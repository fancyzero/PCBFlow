using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
[ExecuteInEditMode]
public class PCBFlowMapGenerator : MonoBehaviour
{
	[Range(0,200)]
	public int detectThreshold=32;
[Range(0,200)]
	public int detectThreshold2=64;	
    public ComputeShader floodShader;
	public ComputeShader preProcessShader;
	public Texture2D initialTexture;
	public Texture2D kernelTexture;
	public Texture2D kernelTexture2;
    public RenderTexture textureFlowMap;
	public RenderTexture textureAnnularRingDetect;

	public Renderer annularRingDetectedDisplay;
	public Renderer flowMapDisplay;
	

    // Use this for initialization
    private IEnumerator coroutine;

	static void OnSceneGUI(SceneView sceneView)
	{
		Handles.BeginGUI();
		if (GUI.Button(new Rect(0,0,100,100),"Run Demo")) 
		{
			RunDemo();
		}

		Handles.EndGUI();
	}

    // [MenuItem("PCBFlowMap/Run Demo")]
    public static void RunDemo()
    {
        var ffp = Object.FindObjectOfType<PCBFlowMapGenerator>();

        // if (ffp == null)
        // {
        //     var newObj = new GameObject("pcbfill");
        //     ffp = newObj.AddComponent<PCBFlowMapGenerator>();
		// 	ffp.floodShader = AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/FloodFill.compute");
		// 	ffp.preProcessShader = AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/CircleDetect.compute");
        // }

        ffp.StartFillPCB();
    }

	void OnEnable()
	{
		SceneView.duringSceneGui += OnSceneGUI;
	}

	void OnDisable()
	{
		SceneView.duringSceneGui -= OnSceneGUI;
	}

	ComputeBuffer buffer ;
    public void StartFillPCB()
    {
		
        textureFlowMap = new RenderTexture(initialTexture.width, initialTexture.height, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
        textureFlowMap.enableRandomWrite = true;
        textureFlowMap.Create();

        textureAnnularRingDetect = new RenderTexture(initialTexture.width, initialTexture.height, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
        textureAnnularRingDetect.enableRandomWrite = true;
        textureAnnularRingDetect.Create();
		
        coroutine = Iterate();
		flowMapDisplay.sharedMaterial.mainTexture = textureFlowMap;
		annularRingDetectedDisplay.sharedMaterial.mainTexture = textureAnnularRingDetect;
        StartCoroutine(coroutine);
    }


    // Update is called once per frame
    public IEnumerator Iterate()
    {

		var kDetectCircle = preProcessShader.FindKernel("CSDetectCircle");
		var kInitDetect = preProcessShader.FindKernel("CSInit");
		var kResolveDetect = preProcessShader.FindKernel("CSResolve");

		preProcessShader.SetTexture(kInitDetect,"Result", textureAnnularRingDetect );
		preProcessShader.Dispatch(kInitDetect,initialTexture.width/32, initialTexture.height/32,1);

		preProcessShader.SetTexture(kDetectCircle,"Input", initialTexture );
		preProcessShader.SetTexture(kDetectCircle,"Result", textureAnnularRingDetect );
		preProcessShader.SetTexture(kDetectCircle,"Kernel", kernelTexture );
		preProcessShader.SetInt("kernelSize",kernelTexture.width);
		preProcessShader.SetInt("threshold", detectThreshold);
		preProcessShader.Dispatch(kDetectCircle,initialTexture.width/32, initialTexture.height/32,1);

		preProcessShader.SetTexture(kResolveDetect,"Result", textureAnnularRingDetect );
		preProcessShader.SetTexture(kResolveDetect,"Input", initialTexture );
		preProcessShader.Dispatch(kResolveDetect,initialTexture.width/32, initialTexture.height/32,1);

		yield return null;
		buffer = new ComputeBuffer(initialTexture.width*initialTexture.height, 4*7);
		var kInit = floodShader.FindKernel("CSInit");
		var kFlood = floodShader.FindKernel("CSFlood");
		var kResolve = floodShader.FindKernel("CSResolve");
		floodShader.SetInts("_Dimensions", initialTexture.width,initialTexture.height);
		floodShader.SetBuffer(kInit,"pixels", buffer);
		floodShader.SetTexture(kInit,"Mask",initialTexture);	
		floodShader.Dispatch(kInit,initialTexture.width/32, initialTexture.height/32,1);

		floodShader.SetBuffer(kResolve,"pixels", buffer);
		floodShader.SetTexture(kResolve,"Result",textureFlowMap);			
		floodShader.Dispatch(kResolve,initialTexture.width/32, initialTexture.height/32,1);

		yield return null;
		for ( int i = 0; i < 1000*3; i++)
		{
			Debug.Log(i);
			floodShader.SetFloat("iter",i+1);
			//------flood
			floodShader.SetBuffer(kFlood,"pixels", buffer);
			floodShader.Dispatch(kFlood,initialTexture.width/32, initialTexture.height/32,1);
			//------resolve
			floodShader.SetBuffer(kResolve,"pixels", buffer);
			floodShader.SetTexture(kResolve,"Result",textureFlowMap);			
			floodShader.Dispatch(kResolve,initialTexture.width/32, initialTexture.height/32,1);		
			yield return null;


		}
		buffer.Release();

		Texture2D textureAsset = new Texture2D(textureFlowMap.width,textureFlowMap.height, UnityEngine.Experimental.Rendering.DefaultFormat.HDR, UnityEngine.Experimental.Rendering.TextureCreationFlags.None);
		RenderTexture.active = (textureFlowMap);
		textureAsset.ReadPixels(new Rect(0,0,textureFlowMap.width,textureFlowMap.height), 0,0);
		RenderTexture.active = (null);
		AssetDatabase.CreateAsset(textureAsset, "Assets/pcb4.asset");
		yield return null;
		
    }
}

