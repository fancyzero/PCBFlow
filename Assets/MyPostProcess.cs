using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
[ExecuteAlways]
public class MyPostProcess : MonoBehaviour
{
    public Shader myShader;
    public CommandBuffer commandBuffer;
    RenderTexture myTarget;
    public Material myMaterial;
    // Start is called before the first frame update
    void Start()
    {

    }
    void OnEnable()
    {
        commandBuffer = new CommandBuffer();
        commandBuffer.name = "my post process";
        GetComponent<Camera>().AddCommandBuffer(CameraEvent.BeforeImageEffects, commandBuffer);
        var cam = GetComponent<Camera>();
        myTarget = new RenderTexture(cam.pixelWidth, cam.pixelHeight, 0, UnityEngine.Experimental.Rendering.DefaultFormat.HDR);
        myTarget.Create();
    }

    void OnDisable()
    {
        GetComponent<Camera>().RemoveCommandBuffer(CameraEvent.BeforeImageEffects, commandBuffer);
        commandBuffer.Release();
        myTarget.Release();
    }
    // Update is called once per frame
    void Update()
    {
        var camera = GetComponent<Camera>();
        Matrix4x4 viewMat = camera.worldToCameraMatrix;
        Matrix4x4 projMat = GL.GetGPUProjectionMatrix(camera.projectionMatrix, false);
        Matrix4x4 viewProjMat = (projMat * viewMat);
        Shader.SetGlobalMatrix("_ViewProjInv", viewProjMat.inverse);

        commandBuffer.Clear();
        commandBuffer.Blit(new RenderTargetIdentifier(BuiltinRenderTextureType.Depth), new RenderTargetIdentifier(myTarget), myMaterial);
        commandBuffer.Blit(new RenderTargetIdentifier(myTarget), new RenderTargetIdentifier(BuiltinRenderTextureType.CameraTarget));
    }
}
