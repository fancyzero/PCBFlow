using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
[ExecuteInEditMode]
public class PCBFlowMapGenerator : MonoBehaviour
{
    [Range(0, 200)]
    public int detectThreshold = 32;
    [Range(0, 200)]
    public int detectThreshold2 = 64;
    public ComputeShader floodShader;
    public ComputeShader preProcessShader;
    public Texture2D initialTexture;
    public Texture2D kernelTexture;
    public Texture2D kernelTexture2;
    public RenderTexture textureFlowMap;
    public RenderTexture textureAnnularRingDetect;

    public Renderer annularRingDetectedDisplay;
    public Renderer processResultDisplay;
    public Renderer flowMapDisplay;

    bool stop;

    // Use this for initialization
    private IEnumerator currentCoroutine;

    static void OnSceneGUI(SceneView sceneView)
    {
        Handles.BeginGUI();
        if (GUI.Button(new Rect(0, 0, 100, 100), "Run Demo"))
        {
            RunDemo();
        }
        if (GUI.Button(new Rect(100, 0, 100, 100), "Stop & Save"))
        {
            var ffp = Object.FindObjectOfType<PCBFlowMapGenerator>();
            ffp.stop = true;
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

    ComputeBuffer bufferA;
    ComputeBuffer bufferB;
    public void StartFillPCB()
    {
        if (currentCoroutine != null)
            StopCoroutine(currentCoroutine);
        stop = false;
        if (textureFlowMap != null)
            textureFlowMap.Release();
        if (textureAnnularRingDetect != null)
            textureAnnularRingDetect.Release();
        if (bufferA != null)
            bufferA.Release();
        if (bufferB != null)
            bufferB.Release();

        textureFlowMap = new RenderTexture(initialTexture.width, initialTexture.height, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
        textureFlowMap.enableRandomWrite = true;
        textureFlowMap.wrapMode = TextureWrapMode.Repeat;
        textureFlowMap.filterMode = FilterMode.Point;
        textureFlowMap.Create();

        textureAnnularRingDetect = new RenderTexture(initialTexture.width, initialTexture.height, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
        textureAnnularRingDetect.enableRandomWrite = true;
        textureAnnularRingDetect.Create();

        processResultDisplay.sharedMaterial.mainTexture = textureFlowMap;
        annularRingDetectedDisplay.sharedMaterial.mainTexture = textureAnnularRingDetect;
        flowMapDisplay.sharedMaterial.mainTexture = textureFlowMap;

        currentCoroutine = Iterate();
        StartCoroutine(currentCoroutine);


    }


    // Update is called once per frame
    public IEnumerator Iterate()
    {

        var kDetectCircle = preProcessShader.FindKernel("CSDetectCircle");
        var kInitDetect = preProcessShader.FindKernel("CSInit");
        var kResolveDetect = preProcessShader.FindKernel("CSResolve");

        preProcessShader.SetTexture(kInitDetect, "Result", textureAnnularRingDetect);
        preProcessShader.Dispatch(kInitDetect, initialTexture.width / 32, initialTexture.height / 32, 1);
        yield return null;
        preProcessShader.SetTexture(kDetectCircle, "Input", initialTexture);
        preProcessShader.SetTexture(kDetectCircle, "Result", textureAnnularRingDetect);
        preProcessShader.SetTexture(kDetectCircle, "Kernel", kernelTexture);
        preProcessShader.SetInt("kernelSize", kernelTexture.width);
        preProcessShader.SetInt("threshold", detectThreshold);
        preProcessShader.Dispatch(kDetectCircle, initialTexture.width / 32, initialTexture.height / 32, 1);
        yield return null;

        preProcessShader.SetTexture(kResolveDetect, "Result", textureAnnularRingDetect);
        preProcessShader.SetTexture(kResolveDetect, "Input", initialTexture);
        preProcessShader.Dispatch(kResolveDetect, initialTexture.width / 32, initialTexture.height / 32, 1);
        yield return null;

        bufferA = new ComputeBuffer(textureAnnularRingDetect.width * textureAnnularRingDetect.height, 4 * 8);
        bufferB = new ComputeBuffer(textureAnnularRingDetect.width * textureAnnularRingDetect.height, 4 * 8);
        var kInit = floodShader.FindKernel("CSInit");
        var kFlood = floodShader.FindKernel("CSFlood");
        var kResolve = floodShader.FindKernel("CSResolve");
        floodShader.SetInts("_Dimensions", textureAnnularRingDetect.width, textureAnnularRingDetect.height);
        floodShader.SetBuffer(kInit, "pixels", bufferA);
        floodShader.SetTexture(kInit, "Mask", textureAnnularRingDetect);
        floodShader.Dispatch(kInit, textureAnnularRingDetect.width / 8, textureAnnularRingDetect.height / 8, 1);
        yield return null;
        floodShader.SetBuffer(kResolve, "pixels", bufferA);
        floodShader.SetTexture(kResolve, "Result", textureFlowMap);
        floodShader.Dispatch(kResolve, textureFlowMap.width / 8, textureFlowMap.height / 8, 1);

        yield return null;
        while (!stop)
        {
            //------flood
            floodShader.SetBuffer(kFlood, "pixels", bufferA);
            floodShader.SetBuffer(kFlood, "pixelsOutput", bufferB);
            floodShader.Dispatch(kFlood, initialTexture.width / 8, initialTexture.height / 8, 1);
            //------resolve
            floodShader.SetBuffer(kResolve, "pixels", bufferB);
            floodShader.SetTexture(kResolve, "Result", textureFlowMap);
            floodShader.Dispatch(kResolve, textureAnnularRingDetect.width / 8, textureAnnularRingDetect.height / 8, 1);

            var tmp = bufferA;
            bufferA = bufferB;
            bufferB = tmp;

            yield return null;

        }


        Texture2D textureAsset = new Texture2D(textureFlowMap.width, textureFlowMap.height, UnityEngine.Experimental.Rendering.DefaultFormat.HDR, UnityEngine.Experimental.Rendering.TextureCreationFlags.None);
        RenderTexture.active = (textureFlowMap);
        textureAsset.ReadPixels(new Rect(0, 0, textureFlowMap.width, textureFlowMap.height), 0, 0);
        RenderTexture.active = (null);
        textureAsset.EncodeToEXR(Texture2D.EXRFlags.OutputAsFloat);
        File.WriteAllBytes("Assets/PCBFlow.exr", textureAsset.EncodeToEXR());
        yield return null;

    }
}

