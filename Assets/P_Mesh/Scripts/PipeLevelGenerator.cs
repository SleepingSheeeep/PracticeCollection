using System.Collections.Generic;
using UnityEngine;

/// <summary>运行时解析 txt、按配置程序化生成关卡。挂到场景物体上，填入 config 后 Play 即自动生成。</summary>
public class PipeLevelGenerator : MonoBehaviour
{
    [SerializeField] PipeLevelConfig config;
    [SerializeField] bool generateColliders = true;
    [SerializeField] Shader pipeShader; // 留空则使用内置 Standard
    [Range(0f, 1f)] [SerializeField] float smoothness = 0.6f;
    [Range(0f, 1f)] [SerializeField] float metallic = 0.1f;

    Transform pipesRoot;
    PipeLevelData data;

    void Start()
    {
        Generate();
    }

    [ContextMenu("Generate (Play Mode)")]
    public void Generate()
    {
        if (!Application.isPlaying)
        {
            Debug.LogWarning("PipeLevelGenerator 请在 Play 模式下生成。");
            return;
        }
        if (config == null)
        {
            Debug.LogError("PipeLevelGenerator: 未设置 config。");
            return;
        }
        if (config.levelFile == null)
        {
            Debug.LogError("PipeLevelGenerator: 未设置 levelFile（关卡 txt）。");
            return;
        }

        Clear();
        data = PipeLevelParser.Parse(config.levelFile.text);
        if (data.n < 1 || data.paths.Count == 0)
        {
            Debug.LogError("关卡解析失败，请检查 txt 格式。");
            return;
        }

        ValidateCoverage();

        pipesRoot = new GameObject("Pipes").transform;
        pipesRoot.SetParent(transform, false);

        Shader shader = pipeShader != null ? pipeShader : Shader.Find("Standard");

        for (int i = 0; i < data.paths.Count; i++)
        {
            PipePath path = data.paths[i];
            path.color = config.palette != null ? config.palette.RandomColor() : RandomFallbackColor();

            Mesh mesh = PipeMeshBuilder.Build(path, config, data);
            if (mesh == null) continue;

            var go = new GameObject("Pipe_" + i);
            go.transform.SetParent(pipesRoot, false);

            var mf = go.AddComponent<MeshFilter>();
            mf.sharedMesh = mesh;

            var mr = go.AddComponent<MeshRenderer>();
            var mat = new Material(shader);
            mat.color = path.color;
            mat.SetFloat("_Glossiness", smoothness);
            mat.SetFloat("_Metallic", metallic);
            mr.sharedMaterial = mat;

            if (generateColliders)
            {
                var col = go.AddComponent<MeshCollider>();
                col.sharedMesh = mesh;
            }
        }
    }

    static Color RandomFallbackColor()
    {
        return Color.HSVToRGB(Random.value, 0.7f, 0.9f);
    }

    /// <summary>销毁上一次生成的物体及其 mesh / 材质，避免运行时泄漏。</summary>
    void Clear()
    {
        if (pipesRoot == null) return;

        var renderers = pipesRoot.GetComponentsInChildren<Renderer>(true);
        foreach (var r in renderers)
            if (r.sharedMaterial != null) Destroy(r.sharedMaterial);

        var filters = pipesRoot.GetComponentsInChildren<MeshFilter>(true);
        foreach (var f in filters)
            if (f.sharedMesh != null) Destroy(f.sharedMesh);

        Destroy(pipesRoot.gameObject);
        pipesRoot = null;
    }

    /// <summary>校验路径坐标合法、无重复，并提示是否填满整个关卡。</summary>
    void ValidateCoverage()
    {
        int n = data.n;
        var seen = new HashSet<Vector3Int>();
        bool error = false;

        foreach (var path in data.paths)
        {
            foreach (var c in path.points)
            {
                if (c.x < 0 || c.y < 0 || c.z < 0 || c.x >= n || c.y >= n || c.z >= n)
                {
                    Debug.LogError($"路径坐标越界：{c}（应在 [0,{n}) 内）");
                    error = true;
                    continue;
                }
                if (!seen.Add(c))
                {
                    Debug.LogError($"路径坐标重复：{c}");
                    error = true;
                }
            }
        }

        if (!error && seen.Count != n * n * n)
            Debug.LogWarning($"关卡未填满：已覆盖 {seen.Count}/{n * n * n} 个单元。");
    }
}
