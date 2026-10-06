using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>解析出的关卡数据（运行时）。</summary>
public class PipeLevelData
{
    /// <summary>关卡维度 n。</summary>
    public int n;
    /// <summary>全部管道。</summary>
    public List<PipePath> paths = new List<PipePath>();

    /// <summary>网格坐标 → 该单元中心的世界坐标。</summary>
    public Vector3 GridToWorld(Vector3Int c, PipeLevelConfig cfg)
    {
        Vector3 basePos = cfg.centerLevel
            ? new Vector3(-n, -n, -n) * (cfg.cellSize * 0.5f)
            : cfg.origin;
        return basePos + ((Vector3)c + Vector3.one * 0.5f) * cfg.cellSize;
    }
}

/// <summary>解析固定格式的关卡 txt。</summary>
public static class PipeLevelParser
{
    /// <summary>
    /// 格式：第一行 n；之后每行一条管道的坐标序列。
    /// 坐标内用逗号分隔 x,y,z；坐标之间用空格或分号分隔；支持 # 开头注释与空行。
    /// </summary>
    public static PipeLevelData Parse(string text)
    {
        var data = new PipeLevelData();
        if (string.IsNullOrWhiteSpace(text))
        {
            Debug.LogError("关卡 txt 为空。");
            return data;
        }

        // 过滤空行与 # 注释。
        var lines = new List<string>();
        foreach (var raw in text.Split('\n'))
        {
            string line = raw.Trim();
            if (line.Length == 0 || line.StartsWith("#")) continue;
            lines.Add(line);
        }

        if (lines.Count < 1)
        {
            Debug.LogError("关卡 txt 没有有效内容。");
            return data;
        }

        if (!int.TryParse(lines[0], out int n) || n < 1)
        {
            Debug.LogError($"关卡 txt 第一行应为 n（正整数），实际为：{lines[0]}");
            return data;
        }
        data.n = n;

        for (int i = 1; i < lines.Count; i++)
        {
            var path = new PipePath();
            // 坐标之间用分号或空白分隔，坐标内用逗号分隔 x,y,z。
            foreach (var token in lines[i].Split(new[] { ';', ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries))
            {
                if (TryParseCoord(token, out Vector3Int c))
                    path.points.Add(c);
            }

            if (path.points.Count > 0)
                data.paths.Add(path);
            else
                Debug.LogWarning($"第 {i + 1} 行未解析出任何坐标，已跳过：{lines[i]}");
        }

        return data;
    }

    static bool TryParseCoord(string s, out Vector3Int c)
    {
        c = default;
        var parts = s.Split(',');
        if (parts.Length != 3) return false;
        if (!int.TryParse(parts[0].Trim(), out int x)) return false;
        if (!int.TryParse(parts[1].Trim(), out int y)) return false;
        if (!int.TryParse(parts[2].Trim(), out int z)) return false;
        c = new Vector3Int(x, y, z);
        return true;
    }
}
