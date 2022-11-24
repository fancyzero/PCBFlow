using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[ExecuteAlways]
public class cheapfog : MonoBehaviour
{
    public Material mat;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dest) {

        Graphics.Blit( src, dest, mat);
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
