import cv2
from scipy.signal import convolve2d
import numpy as np
import math
from scipy import ndimage
circle_radius = 12

kernel = np.zeros((2*circle_radius,2*circle_radius),dtype=int)
for i in range(kernel.shape[0]):
    for j in range(kernel.shape[1]):
        dist = math.sqrt(( i-circle_radius)**2+( j-circle_radius)**2)
        if  dist > circle_radius-1 and dist <=circle_radius :
            kernel[i,j]=1
        else:
            kernel[i,j] = 0
            
ksum = kernel.sum()
img = cv2.imread("test.bmp",cv2.IMREAD_GRAYSCALE)

img= np.minimum(1,img)
cc = convolve2d(img, kernel,mode="same")

cc  -=ksum-1
cc = np.maximum(0,cc)
cc *= 100
cc = cc.astype('uint8')
cv2.imshow('result',cc)
cv2.imwrite( "result.bmp", cc)

