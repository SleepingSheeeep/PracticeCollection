using System.Collections.Generic;
using UnityEngine;

/// <summary>负责把一条管道路径构建成 mesh（采样 / 圆角 / 扫掠 / 顶点）。</summary>
public static class PipeMeshBuilder
{
    struct Sample
    {
        public Vector3 pos;     // 采样点位置
        public Vector3 tangent; // 切向
        public float t;         // 沿路径归一化参数 0..1
        public float radius;    // 该处截面半径
        public Vector3 n;       // 截面法向（frame）
        public Vector3 b;       // 截面副法向（frame）
    }

    public static Mesh Build(PipePath path, PipeLevelConfig cfg, PipeLevelData data)
    {
        var pts = new List<Vector3>();
        foreach (var c in path.points)
            pts.Add(data.GridToWorld(c, cfg));

        if (pts.Count < 2)
        {
            Debug.LogWarning("PipePath 坐标不足 2 个，已跳过。");
            return null;
        }

        // 圆角半径不能超过单元的一半，否则相邻拐角重叠。
        float bendRadius = Mathf.Min(cfg.bendRadius, cfg.cellSize * 0.49f);

        var samples = SamplePath(pts, bendRadius, cfg.straightStep);
        AssignRadiusAndFrame(samples, cfg);
        return BuildMesh(samples, cfg.radialSegments);
    }

    /// <summary>沿路径采样（直线段 + 拐角圆角圆弧），返回位置与切向。</summary>
    static List<Sample> SamplePath(List<Vector3> pts, float bendRadius, float step)
    {
        int k = pts.Count - 1;
        var dir = new Vector3[k];
        for (int i = 0; i < k; i++)
            dir[i] = (pts[i + 1] - pts[i]).normalized;

        var raw = new List<Sample>();

        for (int i = 0; i < k; i++)
        {
            // 直线段 i 的起止点（被相邻拐角的圆角截短）。
            Vector3 start = (i > 0 && IsTurn(dir, i)) ? pts[i] + bendRadius * dir[i] : pts[i];
            Vector3 end = (i < k - 1 && IsTurn(dir, i + 1)) ? pts[i + 1] - bendRadius * dir[i] : pts[i + 1];

            float len = Vector3.Distance(start, end);
            int n = Mathf.Max(1, Mathf.CeilToInt(len / step));
            for (int s = 0; s < n; s++)
            {
                var sm = new Sample();
                sm.pos = Vector3.Lerp(start, end, s / (float)n);
                sm.tangent = dir[i];
                raw.Add(sm);
            }

            // 在 pts[i+1] 处拐弯时，采样圆角圆弧（不含终点，终点交给下一段直线）。
            if (i < k - 1 && IsTurn(dir, i + 1))
                AddArc(raw, pts[i + 1], dir[i], dir[i + 1], bendRadius, step);
        }

        // 补上路径终点。
        var last = new Sample();
        last.pos = pts[k];
        last.tangent = dir[k - 1];
        raw.Add(last);
        return raw;
    }

    /// <summary>j 是内部点索引，判断在 pts[j] 处是否拐弯（相邻两段方向不一致）。</summary>
    static bool IsTurn(Vector3[] dir, int j)
    {
        return Vector3.Dot(dir[j - 1], dir[j]) < 0.9999f;
    }

    /// <summary>采样一段圆弧弯管（从进入切点 A 到离开切点 B，不含 B）。</summary>
    static void AddArc(List<Sample> raw, Vector3 O, Vector3 a, Vector3 b, float r, float step)
    {
        Vector3 axis = Vector3.Cross(a, b).normalized;
        float theta = Mathf.Acos(Mathf.Clamp(Vector3.Dot(a, b), -1f, 1f));
        // 圆心到拐点的距离 = r / sin(theta/2)，方向为内角平分线 normalize(b - a)。
        Vector3 center = O + (b - a).normalized * (r / Mathf.Sin(theta * 0.5f));
        Vector3 A = O - r * a; // 进入切点
        Vector3 B = O + r * b; // 离开切点
        Vector3 from = A - center;
        float angle = Vector3.SignedAngle(from, B - center, axis);

        float arcLen = Mathf.Abs(angle) * Mathf.Deg2Rad * r;
        int m = Mathf.Max(2, Mathf.CeilToInt(arcLen / step));
        for (int s = 0; s < m; s++)
        {
            Quaternion q = Quaternion.AngleAxis(angle * s / (float)m, axis);
            var sm = new Sample();
            sm.pos = center + q * from;
            sm.tangent = q * a;
            raw.Add(sm);
        }
    }

    /// <summary>计算每个采样点的半径与旋转最小化 frame。</summary>
    static void AssignRadiusAndFrame(List<Sample> samples, PipeLevelConfig cfg)
    {
        // 累积弧长。
        var acc = new float[samples.Count];
        for (int i = 1; i < samples.Count; i++)
            acc[i] = acc[i - 1] + Vector3.Distance(samples[i - 1].pos, samples[i].pos);
        float total = acc[acc.Length - 1];

        // 初始 frame：任取一个不与切向平行的参考方向。
        Vector3 t0 = samples[0].tangent;
        Vector3 n = Mathf.Abs(t0.y) < 0.9f ? Vector3.up : Vector3.forward;
        n = (n - t0 * Vector3.Dot(n, t0)).normalized;

        for (int i = 0; i < samples.Count; i++)
        {
            var s = samples[i];
            s.t = total > 1e-5f ? acc[i] / total : 0f;
            s.radius = cfg.RadiusAt(s.t);

            if (i > 0)
                n = Quaternion.FromToRotation(samples[i - 1].tangent, s.tangent) * n;

            Vector3 b = Vector3.Cross(s.tangent, n);
            s.n = n;
            s.b = b;
            samples[i] = s;
        }
    }

    /// <summary>根据采样点生成圆柱侧面 + 两端盖的 mesh。</summary>
    static Mesh BuildMesh(List<Sample> samples, int radialSegments)
    {
        int ringCount = samples.Count;
        var verts = new List<Vector3>(ringCount * radialSegments + 2);
        var normals = new List<Vector3>(verts.Capacity);
        var uvs = new List<Vector2>(verts.Capacity);

        // 每圈 radialSegments 个顶点。
        for (int i = 0; i < ringCount; i++)
        {
            Sample s = samples[i];
            for (int k = 0; k < radialSegments; k++)
            {
                float a = k / (float)radialSegments * 2f * Mathf.PI;
                Vector3 d = (s.n * Mathf.Cos(a) + s.b * Mathf.Sin(a)).normalized;
                verts.Add(s.pos + d * s.radius);
                normals.Add(d);
                uvs.Add(new Vector2(k / (float)radialSegments, s.t));
            }
        }

        var tris = new List<int>();
        // 侧面（环 i 与 i+1 之间的四边形带）。
        for (int i = 0; i < ringCount - 1; i++)
        {
            for (int k = 0; k < radialSegments; k++)
            {
                int k2 = (k + 1) % radialSegments;
                int a = i * radialSegments + k;
                int b = i * radialSegments + k2;
                int c = (i + 1) * radialSegments + k;
                int d = (i + 1) * radialSegments + k2;
                tris.Add(a); tris.Add(c); tris.Add(b);
                tris.Add(b); tris.Add(c); tris.Add(d);
            }
        }

        // 两端盖中心顶点。
        int startCenter = ringCount * radialSegments;
        int endCenter = startCenter + 1;
        verts.Add(samples[0].pos);
        normals.Add(-samples[0].tangent);
        uvs.Add(new Vector2(0.5f, 0f));
        verts.Add(samples[ringCount - 1].pos);
        normals.Add(samples[ringCount - 1].tangent);
        uvs.Add(new Vector2(0.5f, 1f));

        // 端盖（三角形扇形）。
        for (int k = 0; k < radialSegments; k++)
        {
            int k2 = (k + 1) % radialSegments;
            int v0 = k;
            int v1 = k2;
            int vl = (ringCount - 1) * radialSegments + k;
            int vl2 = (ringCount - 1) * radialSegments + k2;
            tris.Add(startCenter); tris.Add(v0); tris.Add(v1);     // 起点盖，法线朝 -tangent
            tris.Add(endCenter); tris.Add(vl2); tris.Add(vl);      // 终点盖，法线朝 +tangent
        }

        var mesh = new Mesh { name = "Pipe" };
        mesh.SetVertices(verts);
        mesh.SetNormals(normals);
        mesh.SetUVs(0, uvs);
        mesh.SetTriangles(tris, 0);
        mesh.RecalculateBounds();
        return mesh;
    }
}
