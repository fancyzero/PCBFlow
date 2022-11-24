using UnityEngine;

public class FloodFill
{
	public static int Result;
	public static int pixels;
	public static int pixelsOutput;
	public static int Mask;
	public static int _Dimensions;

	public static int CSInit { get; set; }
	public static int CSFlood { get; set; }
	public static int CSResolve { get; set; }

	public static void Setup(ComputeShader cs)
	{
		foreach (var info in typeof(FloodFill).GetFields())
		{
			var index = Shader.PropertyToID(info.Name);
			info.SetValue(null, index);
		}
		foreach (var info in typeof(FloodFill).GetProperties())
		{
            try
            {
                var index = cs.FindKernel(info.Name);
                info.SetValue(null, index);
            }
            catch
            {
                continue;
            }
		}
	}
}