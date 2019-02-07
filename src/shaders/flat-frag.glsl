#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
uniform float u_Anim; // for animation of the scene
uniform float u_ColorsOn; // for animation of the colors
uniform float u_Speed; // for speed of animation
uniform vec3 u_BombOffset; // for changing bomb's position with GUI

in vec2 fs_Pos; // the NDC coords, project a ray from this pixel
out vec4 out_Col;

const int RAY_STEPS = 100;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.0001;
const float PI = 3.14159;

// Operations
// polynomial smooth min (k = 0.1);
float smin( float a, float b, float k )
{
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}
//Union
float unionOp( float d1, float d2){
    return smin(d1,d2, 0.1); // smooth
}

//Substraction 
// d1 - d2
float subOp( float d1, float d2 ){
    return max(-d1,d2);
}

//Intersection 
float intersectOp( float d1, float d2 ){
    return max(d1,d2);
}

// rotations
vec3 rotateZ(vec3 p, float a){
  return vec3(cos(a)*p.x - sin(a)*p.y, sin(a)*p.x + cos(a)*p.y, p.z);
}

// rotation
vec2 rot(vec2 v, float y){
    return cos(y)*v + sin(y)*vec2(-v.y, v.x);
}

// Min, pick color of closest object
// pick the vector for the closests object so you grab the correct color along with position
vec3 minVec(vec3 a, vec3 b){
    if (a.x < b.x) {
        return a;
    }
    return b;
}

// tool box function
float bias(float b, float t){
return pow(t, log(b) / log(0.5f));
}

float gain(float g, float t){
  if(t < 0.5f){
    return bias(1.0 - g, 2.0 * t) / 2.0;
  }
  else{
    return 1.0 - bias(1.0 - g, 2.0 - 2.0 * t) / 2.0;
  }
}

// toolbox
float easeInQuadratic(float t){
  return t*t;
}
float easeInOutQuadratic(float t){
  if(t < 0.5){
    return easeInQuadratic(t * 2.0) / 2.0;
  }
  else{
    return 1.0 - easeInQuadratic((1.0 - t) * 2.0) / 2.0;
  }
}

// toolbox function
float square_wave(float x, float freq, float amp){
  return abs(mod(floor(x * freq),2.0) * amp);
}

// toolbox function
float sawtoothWave(float x, float freq, float amp){
  return (x * freq - floor(x * freq)) * amp;
}

// Shapes
// from http://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
// Sphere
float sphereSDF(vec3 point, float r){
  return length(point) - r;
}

// Torus
float torusSDF( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}
// Round Box
float roundBoxSDF(vec3 p, vec3 b, float r){
  vec3 d = abs(p) - b;
  return length(max(d,0.0)) - r + min(max(d.x,max(d.y,d.z)),0.0);
}

// Box
float boxSDF( vec3 p, vec3 b )
{
  vec3 d = abs(p) - b;
  return length(max(d,0.0))
         + min(max(d.x,max(d.y,d.z)),0.0); // remove this line for an only partially signed sdf 
}

// Cylinder
float cylinderSDF(vec3 p, vec3 c){
  return length(p.xz - c.xy) - c.z;
}

// Capped Cylinder
float cappedCylinderSDF(vec3 p, vec2 h)
{
  vec2 d = abs(vec2(length(p.xz),p.y)) - h;
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

// Capsule
float capsuleSDF( vec3 p, vec3 a, vec3 b, float r )
{
    vec3 pa = p - a, ba = b - a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h ) - r;
}

// Ellipsoid
float ellipsoidSDF(in vec3 p, in vec3 r)
{
  float k0 = length(p/r);
  float k1 = length(p/(r*r));
  return k0 * (k0 - 1.0) / k1;
}

// Triangle
float dot2( in vec3 v ) {  // method used in triangleSDF
  return dot(v,v);
   }


// SceneSDF
// in the vec3 being returned .x is the float, .y is the color ID
vec3 sceneSDF(vec3 point){  
  vec3 bombOffset = vec3(0.0, 8.0, -5.0) + vec3(u_BombOffset.x, -u_BombOffset.y, u_BombOffset.z);

  float rotateControl = u_Time * 0.2 * u_Anim * u_Speed;
  float sawtooth = sawtoothWave(sin(u_Time * 0.04), 2.0, 4.0) * u_Anim * u_Speed;

  float move = 1.0 - (sin(u_Time*0.04* u_Speed) + 1.0) * u_Anim;
  float moveOffset1 = 1.0 - (sin(u_Time*0.04* u_Speed + 1.0) + 1.0)/2.0 * u_Anim;
  float moveOffset2 = 1.0 - (sin(u_Time*0.04* u_Speed + 2.0) + 1.0)/2.0 * u_Anim;
  float moveOffset3 = 1.0 - (sin(u_Time*0.04* u_Speed + 3.0) + 1.0)/2.0 * u_Anim;
  float moveOffset4 = 1.0 - (sin(u_Time*0.04* u_Speed + 4.0) + 1.0)/2.0 * u_Anim;
  float moveOffset5 = 1.0 - (sin(u_Time*0.04* u_Speed + 5.0) + 1.0)/2.0 * u_Anim;
  
  // Chain Chomp
  vec3 pos = vec3(point.x + 7.0, point.y - 1.0, point.z);  
  pos.y = pos.y + move;
  float chomp = sphereSDF(pos, 3.0); // big chomp ball
  //pos = vec3(point.x + 7.0, point.y + 0.7, point.z + 3.0);
  //pos.yz = rot(pos.yz, 0.785398); 
  //float box = boxSDF(pos, vec3(3.0, 0.8, 0.8));
  //chomp = subOp(box, chomp);

  pos = vec3(point.x + 4.0 -0.6, point.y, point.z);
  pos.y = pos.y + moveOffset1; 
  float chain = sphereSDF(pos, 1.0); // smal chain ball rightmost
  pos = vec3(point.x + 2.0 - 0.4, point.y, point.z);
  pos.y = pos.y + moveOffset2;
  chain = unionOp(chain, sphereSDF(pos, 1.0)); // small chain ball two from right
  pos = vec3(point.x - 0.2, point.y, point.z);
  pos.y = pos.y + moveOffset3;
  chain = unionOp(chain, sphereSDF(pos, 1.0)); // small chain ball in middle
  pos = vec3(point.x - 2.0, point.y, point.z);
  pos.y = pos.y + moveOffset4;
  chain = unionOp(chain, sphereSDF(pos, 1.0)); // small chain ball two from right
  pos = vec3(point.x - 4.0 + 0.2, point.y, point.z);
  pos.y = pos.y + moveOffset5;
  chain = unionOp(chain, sphereSDF(pos, 1.0)); // small chain ball leftmost   
  float post = cappedCylinderSDF(point - vec3(6.0, 0.0, 0.0), vec2(1.0, 2.0)); // post
  pos = vec3(point.x + 8.5, point.y - 1.8, point.z + 2.0);
  pos.y = pos.y + move;
  float chompEye1 = ellipsoidSDF(pos, vec3(0.7, 0.7, 0.7));
  pos = vec3(point.x + 5.0, point.y - 1.8, point.z + 1.5);
  pos.y = pos.y + move;
  float chompEye2 = ellipsoidSDF(pos, vec3(0.7, 0.7, 0.7));
  pos = vec3(point.x + 8.6, point.y - 1.9, point.z + 2.5);
  pos.y = pos.y + move;
  float chompInEye1 = ellipsoidSDF(pos, vec3(0.3, 0.3, 0.3));
  pos = vec3(point.x + 4.6, point.y - 1.9, point.z + 2.0);
  pos.y = pos.y + move;
  float chompInEye2 = ellipsoidSDF(pos, vec3(0.3, 0.3, 0.3));

  // Makes Bomb
  float bombBody = sphereSDF(point - vec3(0.0, 15.0, 0.0) + bombOffset, 5.); // Bomb Body
  pos = vec3(point.x - 5.0, point.y - 13.0, point.z) + bombOffset;
  float leftArm = sphereSDF(pos, 1.0); // Bomb left arm 
  pos = vec3(point.x - 7.0, point.y - 11.5, point.z) + bombOffset; 
  pos.xy = rot(pos.xy, PI * mix(0.95, 0.6, move));
  float leftHand = sphereSDF(pos, 2.0); // Bomb left hand 
  leftArm = unionOp(leftArm, leftHand); 
  float rightArm = min(leftArm, sphereSDF(point - vec3(-5.0, 13.0, 0.0) + bombOffset, 1.0)); // Bomb right arm
  pos = vec3(point.x + 7.0, point.y - 11.5, point.z) + bombOffset; 
  float rightHand = sphereSDF(pos, 2.0); // Bomb right hand
  rightArm = unionOp(rightArm, rightHand);
  float leftLeg = sphereSDF(point - vec3(3.0, 10.0, 0.0) + bombOffset, 1.0); // Bomb left leg
  float rightLeg = min(leftLeg, sphereSDF(point - vec3(-3.0, 10.0, 0.0) + bombOffset, 1.0)); // Bomb right leg
  float leftFoot =  ellipsoidSDF(point - vec3(3.0, 8.5, -1.0) + bombOffset, vec3(1.5, 1.0, 2.0)); // Bomb left foot
  float rightFoot = min(leftFoot, ellipsoidSDF(point - vec3(-3.0, 8.5, -1.0) + bombOffset, vec3(1.5, 1.0, 2.0))); // Bomb right foot
  float leftEye = ellipsoidSDF(point - vec3(1.0, 7.4, 0.5) + vec3(u_BombOffset.x, -u_BombOffset.y, u_BombOffset.z), vec3(1.0, 1.25, 1.0));
  float rightEye = ellipsoidSDF(point - vec3(-1.0, 7.4, 0.5) + vec3(u_BombOffset.x, -u_BombOffset.y, u_BombOffset.z), vec3(1.0, 1.25, 1.0));
  float crownBase = cappedCylinderSDF(point - vec3(0.0, 12.0, 5.0) + vec3(u_BombOffset.x, -u_BombOffset.y, u_BombOffset.z), vec2(3.0, 1.0));
  float bodyAndCrown = unionOp(bombBody, crownBase);

  // coin
  vec3 p = point - vec3(8.0, 6.0, 0.0);
  p.xy = rot(p.xy, 1.5708);  
  p.yz = rot(p.yz, sawtooth * 0.15);
  float coin = cappedCylinderSDF(p - vec3(0.0, 0.4, 0.0), vec2(1.0, 0.4));
  float sub1 = cappedCylinderSDF(p, vec2(0.5, 0.2));
  float sub2 = cappedCylinderSDF(p - vec3(0.0, 0.8, 0.0), vec2(0.5, 0.2));
  coin = subOp(sub1, coin);
  coin = subOp(sub2, coin);

  // red coin
  vec3 q = point - vec3(8.0, 6.0, 0.0);
  vec3 redCoinOffset = vec3(3.0, 0.0, 0.0);
  q.xy = rot(q.xy, 1.5708);  
  q.yz = rot(q.yz, rotateControl * -0.25);
  float coinRed = cappedCylinderSDF(q - vec3(0.0, 0.4, 0.0) + redCoinOffset, vec2(1.0, 0.4));
  float s1 = cappedCylinderSDF(q + redCoinOffset , vec2(0.5, 0.2));
  float s2 = cappedCylinderSDF(q - vec3(0.0, 0.8, 0.0) + redCoinOffset, vec2(0.5, 0.2));
  coinRed = subOp(s1, coinRed);
  coinRed = subOp(s2, coinRed);

  // intersection object
  float sw = square_wave(sin(u_Time * 0.04), 4.0, 2.0) * u_Anim;
  pos = point - vec3(-5.0, -5.0, -4.0);
  pos.y = pos.y + sw;
  float e1 = ellipsoidSDF(pos, vec3(5.0, 1.0, 1.0));
  pos = point - vec3(-5.0, -5.0, -4.0);
  pos.y = pos.y + sw;
  float e2 = ellipsoidSDF(pos, vec3(1.0, 5.0, 1.0));  
  e1 = intersectOp(e1, e2);

  // drawing and coloring
  
  vec3 temp = vec3(chomp, 1.0, 0.0); // the chomp is color ID 1
  temp = minVec(temp, vec3(chain, 2.0, 0.0)); // comparing chomp to chain (chain has color ID 2.0)
  temp = minVec(temp, vec3(post, 3.0, 0.0)); // comparing chain to post (post has color ID 3.0)
  temp = minVec(temp, vec3(chompEye1, 10.0, 0.0));
  temp = minVec(temp, vec3(chompEye2, 10.0, 0.0));
  temp = minVec(temp, vec3(chompInEye1, 1.0, 0.0));
  temp = minVec(temp, vec3(chompInEye2, 1.0, 0.0));
  temp = minVec(temp, vec3(bombBody, 1.5, 0.0)); // bomb body  
  temp = minVec(temp, vec3(leftArm, 5.0, 0.0));   
  temp = minVec(temp, vec3(rightArm, 5.0, 0.0)); 
  //temp = minVec(temp, vec3(leftHand, 5.0, 0.0)); 
  //temp = minVec(temp, vec3(rightHand, 5.0, 0.0)); 
  temp = minVec(temp, vec3(leftLeg, 4.0, 0.0)); 
  temp = minVec(temp, vec3(rightLeg, 4.0, 0.0)); 
  temp = minVec(temp, vec3(leftFoot, 5.0, 0.0)); 
  temp = minVec(temp, vec3(rightFoot, 5.0, 0.0)); 
  temp = minVec(temp, vec3(leftEye, 6.0, 0.0));
  temp = minVec(temp, vec3(rightEye, 6.0, 0.0));
  temp = minVec(temp, vec3(crownBase, 7.0, 0.0));
  temp = minVec(temp, vec3(coin, 8.0, 0.0));
  temp = minVec(temp, vec3(coinRed, 9.0, 0.0));
  temp = minVec(temp, vec3(e1, 9.0, 0.0)); // intersection
    
  return temp;
}

// Referenced http://patriciogonzalezvivo.com
float random (in vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123);
}

// Based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
float noise (in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

// based on lecture slides
float fbm (in vec2 st) {
    // Initial values
    float total = 0.0;
    float persist = 0.5;
    int octaves = 6;
    
    // Loop for number of octaves
    for (int i = 0; i < octaves; i++) {
          float frequency = pow(3.0, float(i));
          float amp = pow(persist, float(i));
        total +=  noise(vec2(st.x * frequency, st.y * frequency)) * amp;       
    }
    return total;
}

// calculate normals
vec3 getNormals(vec3 pos) {
   vec3 eps = vec3(0.0, 0.001, 0.0);
    vec3 normals =  normalize(vec3(
        sceneSDF(vec3(pos + eps.yxz)).x - sceneSDF(vec3(pos - eps.yxz)).x,
        sceneSDF(vec3(pos + eps.xyz)).x - sceneSDF(vec3(pos - eps.xyz)).x,
        sceneSDF(vec3(pos + eps.xzy)).x - sceneSDF(vec3(pos - eps.xzy)).x
    ));
   return normals;
}

vec3 march(vec3 origin, vec3 marchDir, float start, float end){
  float t = 0.001;
  vec3 temp = vec3(0.0);
  float dist = 0.0;
  float colorID = 0.0;
  float depth = start;
    
  for (int i = 0; i < RAY_STEPS; i ++){
    vec3 pos = origin + depth * marchDir;
    temp = sceneSDF(pos);
    dist = temp.x; // the minimum distance
    colorID = temp.y; // the color ID
    if(dist < EPSILON){
      //return t;
      return vec3(depth, colorID, 0.0);
    }
    depth += dist;
    if(depth >= end){
      return vec3(end, colorID, 0.0);
    }
  } // closes for loop

  return vec3(end, colorID, 0.0);

}

vec3 getColor(float id, float lightMult, float specVal, vec3 point) {
  vec3 coloring = vec3(0.0);
        
    //float t = (sin((point.x) * 3.14159 * 0.1) + cos((point.y) * 3.14159 * 0.1) * u_Time * u_ColorsOn);
    float sw = square_wave(sin(u_Time * 0.01), 5.0, 2.0) * u_ColorsOn;
    float t = sin(u_Time * 0.05) * u_ColorsOn;

    // Chomp - black, no specular
    if (id == 1.0){
        coloring = vec3(0.0431, 0.0549, 0.0) * lightMult;
        return coloring;
    }
    // Specular black
    if (id == 1.5){
        coloring = vec3(0.0431, 0.0549, 0.0) * lightMult + specVal;
        return coloring;
    }
    // Chain - silver
    if (id == 2.0) {
        coloring = vec3(0.2275, 0.2275, 0.2) * lightMult + specVal;
        return coloring;
    }
    // Post - brown
    if (id == 3.0){   
        coloring = vec3(0.54, 0.27, 0.075) * lightMult;  
        return coloring;
    }    
    // bomb arm/leg color
    if (id == 4.0){
        coloring = vec3(0.0431, 0.102, 0.8863) * lightMult + specVal;
        return coloring;
    }   
    // bomb hand/foot color
    if (id == 5.0){
        coloring = vec3(0.9451, 0.9294, 0.0196) * lightMult;
        vec3 color2 = mix(coloring, vec3(1.0, 0.0, 0.0), t) * lightMult;
        if(u_ColorsOn == 1.0){
          coloring = mix(coloring, color2, t);
        }
        return coloring;
    }   
    // bomb eye color - white to red
    if (id == 6.0){
        coloring = vec3(0.8941, 0.851, 0.851) * lightMult;
         vec3 color2 = mix(coloring, vec3(1.0, 0.0, 0.0), t);
         if(u_ColorsOn == 1.0){
          coloring = mix(coloring, color2, easeInOutQuadratic(t * 2.0));
        }
        return coloring;
    }    
    // crown color
    if (id == 7.0){
        coloring = vec3(0.9529, 0.7804, 0.4118) * lightMult + specVal;
        return coloring;
    } 
    // coin color
    if (id == 8.0){
        coloring = vec3(0.949, 0.9412, 0.4118) * lightMult + specVal;
        coloring *= gain(-2.0, 0.3);
        return coloring;
    } 
    // red coin color
    if (id == 9.0){
        coloring = vec3(0.7529, 0.1686, 0.1451) * lightMult + specVal;
        return coloring;
    } 
    // only white
    if (id == 10.0){
        coloring = vec3(0.8941, 0.851, 0.851) * lightMult;        
        return coloring;
    }   
    return vec3(id / 10.0);
}

void main() {
  // Casting Rays
  vec3 rightVec = normalize(cross((u_Ref - u_Eye), u_Up));
  float FOV = 45.0; // field of view
  float len = length(u_Ref - u_Eye);
  vec3 V = u_Up * len * tan(FOV/2.0);
  vec3 H = rightVec * len * (u_Dimensions.x / u_Dimensions.y) * tan(FOV/2.0);

  vec3 pixel = u_Ref + (fs_Pos.x*H) + (fs_Pos.y*V);
  vec3 dir = normalize(pixel - u_Eye);
  vec3 color = 0.5 * (dir + vec3(1.0, 1.0, 1.0)); // test rays
  
  // ray marching
  vec3 marchVals = march(u_Eye, dir, MIN_DIST, MAX_DIST);
  //float dist = march(u_Eye, dir, MIN_DIST, MAX_DIST);
  //float dist = march(u_Eye, dir);
  float dist = marchVals.x;
  float colorVal = marchVals.y;
  if(dist > 100.0 - EPSILON){
    // not in the shape - color the background    
    vec3 point = u_Eye + marchVals.x * dir; // screen space coord
    vec2 st = point.xy / u_Dimensions.xy; // u_Dimension is screen resolution    
    vec3 color = vec3(0.0, 0.0, 0.0);    
    color += fbm(st * 3.0);
    color *= vec3(0.0, 1.0, 0.0);
    color *= gain(-2.0, 0.3); // toolbox function for coloring
    out_Col = vec4(color, 1.0);
    return;
  }

  // Lighting
  vec3 normals = getNormals(u_Eye + marchVals.x * dir);

  vec3 lightVector = u_Eye; 

  // h is the average of the view and light vectors
  vec3 h = (u_Eye + u_Eye) / 2.0;

  // specular intensity
  float specularInt = max(pow(dot(normalize(h), normalize(normals)), 23.0) , 0.0);  

  vec3 theColor = vec3(1.0, 0.0, 0.0); 
  // dot between normals and light direction
  float diffuseTerm = dot(normalize(normals), normalize(lightVector)); 
  // Avoid negative lighting values 
  diffuseTerm = clamp(diffuseTerm, 0.0, 1.0);
    
  float ambientTerm = 0.2;
  float lightIntensity = diffuseTerm + ambientTerm;

  //vec3 colorVec = vec3(1.0, 0.0, 0.0);
  out_Col = vec4(getColor(colorVal, lightIntensity, specularInt, u_Eye + marchVals.x * dir), 1.0);
  
  //out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
  //out_Col = vec4(color, 1.0);
}
