using System.Collections.Generic;
using UnityEngine;

/// <summary>管道形状类型（整关统一）。</summary>
public enum PipeShape
{
    /// <summary>管道：半径均匀。</summary>
    Pipe,
    /// <summary>箭头：沿路径由尾到头半径渐变。</summary>
    Arrow,
    /// <summary>蛇：半径正弦起伏，末端膨大为蛇头。</summary>
    Snake
}

/// <summary>一条管道的运行时数据：坐标序列 + 颜色（颜色在生成时随机填充）。</summary>
public class PipePath
{
    /// <summary>坐标序列，相邻坐标沿单轴差 1 格，顺序即方向。</summary>
    public List<Vector3Int> points = new List<Vector3Int>();

    /// <summary>管道颜色（生成时从调色板随机）。</summary>
    public Color color = Color.white;
}

/// <summary>颜色调色板（ScriptableObject）。管道颜色从中随机抽取。</summary>
[CreateAssetMenu(menuName = "P_Mesh/Color Palette", fileName = "ColorPalette")]
public class ColorPalette : ScriptableObject
{
    [Tooltip("固定颜色集合，管道颜色从中随机抽取，可增删扩展。")]
    public List<Color> colors = new List<Color>
    {
        new Color(0.95f, 0.30f, 0.30f), // 红
        new Color(1.00f, 0.60f, 0.20f), // 橙
        new Color(1.00f, 0.90f, 0.30f), // 黄
        new Color(0.30f, 0.80f, 0.40f), // 绿
        new Color(0.30f, 0.80f, 0.80f), // 青
        new Color(0.30f, 0.50f, 1.00f), // 蓝
        new Color(0.60f, 0.40f, 1.00f), // 紫
        new Color(1.00f, 0.50f, 0.80f), // 粉
        new Color(0.95f, 0.95f, 0.95f), // 白
        new Color(0.55f, 0.55f, 0.55f), // 灰
    };

    public Color RandomColor()
    {
        if (colors == null || colors.Count == 0) return Color.white;
        return colors[Random.Range(0, colors.Count)];
    }
}

/// <summary>关卡配置（ScriptableObject）。关卡结构由 txt 提供，这里只放生成参数与全局外观。</summary>
[CreateAssetMenu(menuName = "P_Mesh/Pipe Level Config", fileName = "PipeLevelConfig")]
public class PipeLevelConfig : ScriptableObject
{
    [Header("数据源")]
    [Tooltip("固定格式关卡 txt：第一行 n，之后每行一条管道的坐标序列。坐标 x,y,z 用逗号分隔分量，坐标之间用空格或分号分隔。")]
    public TextAsset levelFile;
    [Tooltip("颜色调色板，管道颜色从中随机。")]
    public ColorPalette palette;

    [Header("网格与生成")]
    [Min(0.01f)] public float cellSize = 1f;
    [Range(3, 64)] public int radialSegments = 16;
    [Tooltip("拐角圆角半径，须 <= cellSize/2，超出会自动收紧。")]
    [Min(0.01f)] public float bendRadius = 0.35f;
    [Tooltip("直线段采样步长（世界单位），越小越平滑。")]
    [Min(0.01f)] public float straightStep = 0.25f;

    [Header("摆放")]
    [Tooltip("勾选后关卡中心对齐世界原点；否则 (0,0,0) 单元的左下角对齐 origin。")]
    public bool centerLevel = true;
    [Tooltip("网格左下角的世界坐标（centerLevel 为 false 时生效）。")]
    public Vector3 origin = Vector3.zero;

    [Header("形状（整关统一，每种一个参数）")]
    public PipeShape shape = PipeShape.Pipe;
    [Min(0.01f)] public float pipeRadius = 0.4f;   // 管道半径
    [Min(0.01f)] public float arrowRadius = 0.5f;   // 箭头头部半径（尾部固定为其 30%）
    [Min(0.01f)] public float snakeRadius = 0.4f;   // 蛇身体半径（波动/蛇头按固定比例派生）

    /// <summary>整关统一形状下，某处（t 沿路径 0..1）的截面半径。</summary>
    public float RadiusAt(float t)
    {
        switch (shape)
        {
            case PipeShape.Arrow:
                return Mathf.Lerp(0.3f * arrowRadius, arrowRadius, t);
            case PipeShape.Snake:
                float body = snakeRadius + 0.25f * snakeRadius * Mathf.Sin(t * 3f * 2f * Mathf.PI);
                return Mathf.Lerp(body, 1.4f * snakeRadius, Mathf.InverseLerp(0.7f, 1f, t));
            default:
                return pipeRadius;
        }
    }
}
