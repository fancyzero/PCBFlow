using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
[ExecuteInEditMode]
public class FloodFillPCB : MonoBehaviour
{
    public ComputeShader floodShader;
	public Texture2D initialTexture;
    public RenderTexture texture;

    // Use this for initialization
    private IEnumerator coroutine;

	static void OnScene(SceneView sceneView)
	{
		Handles.BeginGUI();
		if (GUI.Button(new Rect(0,0,100,100),"Fill"))
			FillPCB();
		Handles.EndGUI();
	}

    [MenuItem("sss/sss")]
    public static void FillPCB()
    {
		SceneView.duringSceneGui += OnScene;
        var ffp = Object.FindObjectOfType<FloodFillPCB>();

        if (ffp == null)
        {
            var newObj = new GameObject("pcbfill");
            ffp = newObj.AddComponent<FloodFillPCB>();
			ffp.floodShader = AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/FloodFill.compute");
        }

        ffp.StartFillPCB();
    }

	// void OnEnable()
	// {
	// 	SceneView.onSceneGUIDelegate += OnSceneGUI;
	// }
    // void OnSceneGUI( SceneView sceneView)
    // {
	// 	Handles.BeginGUI();
	// 	GUI.DrawTexture( new Rect(0, 0, 1024, 1024), texture);
	// 	Handles.EndGUI();
		
    // }
	ComputeBuffer buffer ;
	int iters=0;
    public void StartFillPCB()
    {
		
        texture = new RenderTexture(4096, 4096, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
        texture.enableRandomWrite = true;
        texture.Create();

		buffer = new ComputeBuffer(4096*4096, 4*7);
        coroutine = Iterate();
		GetComponentInChildren<Renderer>().sharedMaterial.mainTexture = texture;
        StartCoroutine(coroutine);
    }


    // Update is called once per frame
    public IEnumerator Iterate()
    {
		var kInit = floodShader.FindKernel("CSInit");
		var kFlood = floodShader.FindKernel("CSFlood");
		var kResolve = floodShader.FindKernel("CSResolve");

		floodShader.SetBuffer(kInit,"pixels", buffer);
		floodShader.SetTexture(kInit,"Mask",initialTexture);	
		floodShader.Dispatch(kInit,4096/32,4096/32,1);

		floodShader.SetBuffer(kResolve,"pixels", buffer);
		floodShader.SetTexture(kResolve,"Result",texture);			
		floodShader.Dispatch(kResolve,4096/32,4096/32,1);	

		yield return null;
		for ( int i = 0; i < 1024; i++)
		{
			Debug.Log(i);
			floodShader.SetFloat("iter",i+1);
			//------flood
			floodShader.SetBuffer(kFlood,"pixels", buffer);
			floodShader.Dispatch(kFlood,4096/32,4096/32,1);
			//------resolve
			floodShader.SetBuffer(kResolve,"pixels", buffer);
			floodShader.SetTexture(kResolve,"Result",texture);			
			floodShader.Dispatch(kResolve,4096/32,4096/32,1);			
			yield return null;

			if ( i %100 == 0 )	
			{
				// Texture2D ttt = new Texture2D(4096,4096, UnityEngine.Experimental.Rendering.DefaultFormat.HDR, UnityEngine.Experimental.Rendering.TextureCreationFlags.None);
				// RenderTexture.active = (texture);
				// ttt.ReadPixels(new Rect(0,0,4096,4096), 0,0);
				// RenderTexture.active = (null);
				// AssetDatabase.CreateAsset(ttt, "Assets/pcb4.asset");			
				
			}
		}
		buffer.Release();

		Texture2D textureAsset = new Texture2D(4096,4096, UnityEngine.Experimental.Rendering.DefaultFormat.HDR, UnityEngine.Experimental.Rendering.TextureCreationFlags.None);
		RenderTexture.active = (texture);
		textureAsset.ReadPixels(new Rect(0,0,4096,4096), 0,0);
		RenderTexture.active = (null);
		AssetDatabase.CreateAsset(textureAsset, "Assets/pcb4.asset");
		yield return null;
		
    }
}
