/* By Yeouf Tan 2015, www.yeouf.com*/

import processing.video.*;

Capture cam;
int CAM_ID =1; //Choose your own camera ID base on print out.
static PImage grayImg;
static int w =640, h= 480, size = w*h;
ArrayList<PVector> cornersA ;
float QualityLevel =0.01f; //0.01f~0.1f

void setup() {
  size(w, h);

  String[] cameras = Capture.list();

  if (cameras == null) {
    println("Failed to retrieve the list of available cameras, will try the default...");
    //cam = new Capture(this, 640, 480);
    cam = new Capture(this, w, h);
  } 
  if (cameras.length == 0) {
    println("There are no cameras available for capture.");
    exit();
  } else {
    println("Available cameras:");
    for (int i = 0; i < cameras.length; i++) {
      println(i+","+cameras[i]);
    }

    // The camera can be initialized directly using an element
    // from the array returned by list():
    cam = new Capture(this, cameras[CAM_ID]);
    //cam = new Capture(this, 640, 480);
    // Or, the settings can be defined based on the text in the list
    //cam = new Capture(this, 640, 480, "Built-in iSight", 30);

    // Start capturing the images from the camera
    cam.start();
  }
  grayImg = createImage(w, h, ALPHA );
}

void draw() {
  if (cam.available() == true) {
    cam.read();
  }

  Rgb2Gray(cam.get()); 
  GoodFeaturesToTrack(grayImg.get(), QualityLevel);
  image(cam, 0, 0);
  fill(0, 255, 255);
  if ( cornersA.size()>0)
  {
    // println(cornersA.size());
    for (int i = 0; i < cornersA.size (); i++) 
    {
      PVector pt=cornersA.get(i);
      ellipse(pt.x, pt.y, 3.0f, 3.0f);
    }
  }

  // The following does the same as the above image() line, but 
  // is faster when just drawing the image without any additional 
  // resizing, transformations, or tint.
  //set(0, 0, cam);
}


void Rgb2Gray(PImage srcImg)
{
  grayImg.loadPixels();

  for ( int i =0; i < srcImg.width *srcImg.height; i++)
  {
    color c = srcImg.pixels[i];
    float r= c >> 16 & 0xFF;
    float g= c >> 8 & 0xFF;
    float b= c & 0xFF;
    int val =(int)(r*0.299f + g*0.587f + b* 0.114f);
    grayImg.pixels[i] = color(val, val, val); // Gray value all is same
  }
  grayImg.updatePixels();
}


void GoodFeaturesToTrack(PImage srcImg, float QualityLVL)
{
  int x=0, y=0, index=0, bX=0, bY=0;
  float scale = 1.0f/(12*255), SumX=0.0f, SumY=0.0f, SumXY=0.0f, minEigenVal=0.0f, val=0.0f;
  float[]  buffX = new float[size];
  float[]  buffY = new float[size];
  float[]  Gx = new float[size];
  float[]  Gy = new float[size];
  float[]  dxx = new float[size];
  float[]  dyy = new float[size];
  float[]  dxy = new float[size];
  float[]  eig = new float[size];
  float[]  tempDilate = new float[size];
  int nY=0, BlockIndex=0;
  srcImg.loadPixels();
  cornersA = new ArrayList<PVector>();

  color L=0, R=0, c=0;
  float LGrayVal=0.0f, RGrayVal=0.0f, CGrayVal=0.0f;

  //Sobel Horizontal
  for (  y =0; y <h; y++)
  {
    for (  x =1; x <w-1; x++)
    {
      index = x + y*w;
      L = srcImg.pixels[index-1];
      LGrayVal= L >> 16 & 0xFF;
      R = srcImg.pixels[index+1];
      RGrayVal= R >> 16 & 0xFF;
      c = srcImg.pixels[index];
      CGrayVal= c >> 16 & 0xFF;

      buffX[index] = RGrayVal-LGrayVal;
      buffY[index] = (RGrayVal+ ((int)CGrayVal << 1 )+ LGrayVal)*scale;
    }
  }


  //Sobel Vertical 
  for (  y =1; y <h-1; y++)
  {
    for (  x =0; x <w; x++)
    {

      index = x + y*w;

      Gx[index] = (buffX[index - w] + ((int)buffX[index]<<1) + buffX[index+w] ) * scale;
      Gy[index] =  buffY[index + w] - buffY[index - w];
      dxx[index] = Gx[index]*Gx[index];
      dyy[index] = Gy[index]*Gy[index];
      dxy[index] = Gx[index]*Gy[index];
    }

    if ( y <2) {
      continue;
    }

    nY = y-1;

    // Eigen Value 
    for (  x =1; x <w-1; x++)
    {
      index = x +nY *w;
      SumX=0.0f;
      SumY=0.0f;
      SumXY=0.0f;
      for ( bX = x-1; bX<= x+1; bX++)
      {
        for ( bY = nY-1; bY<= nY+1; bY++)
        {
          BlockIndex = bY*w +bX;

          SumX+=dxx[BlockIndex];
          SumY+=dyy[BlockIndex];
          SumXY+=dxy[BlockIndex];
        }
      }

      eig[index] = MinEigenVal(SumX, SumY, SumXY);

      minEigenVal = eig[index]>minEigenVal? eig[index] : minEigenVal;
    }
  }
  //  println(minEigenVal);
  //Threshold to Zero
  minEigenVal*=QualityLVL;
  for (index =0; index< size; index++)
  {
    val = eig[index] ;

    if ( val == 0.0f || val >= minEigenVal) {
      continue;
    }
    eig[index] = 0.0f;
  }


  //Local Maximun Suppression Using Dilation
  int bSz=(int)(3/2);
  for ( y=bSz; y < h-bSz; y++)
  {
    for ( x=bSz; x < w-bSz; x++)
    {
      index = x +y *w;
      val= eig[index];
      //if( val ==0) {continue;}
      for ( bX = x-bSz; bX<= x+bSz; bX++)
      {
        for ( bY = y-bSz; bY<= y+bSz; bY++)
        {
          BlockIndex = bY*w +bX;
          if (BlockIndex==index || eig[BlockIndex]<=val ) {
            continue;
          }
          val = eig[BlockIndex];
        }
      }
      tempDilate[index]=val;
    }
  }

  for ( y=0; y < h; y++)
  {
    for ( x=0; x < w; x++)
    {
      index = y*w +x;
      if ( eig[index]!=0 && eig[index]==tempDilate[index] )
      {
        PVector pt = new PVector(x, y);

        cornersA.add(pt);
      }
    }
  }
}

float MinEigenVal( float SumX, float SumY, float  SumXY)
{
  if ( SumX==0 && SumY==0 && SumXY==0) {
    return 0.0f;
  }

  float a = SumX* 0.5f;
  float b = SumXY;
  float c = SumY * 0.5f;

  float eig =(float) ((a + c) - sqrt((a - c)*(a - c) + b*b));

  return eig;
}
