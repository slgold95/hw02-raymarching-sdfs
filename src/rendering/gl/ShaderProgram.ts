import {vec2, vec3, vec4, mat4} from 'gl-matrix';
import Drawable from './Drawable';
import {gl} from '../../globals';

var activeProgram: WebGLProgram = null;

export class Shader {
  shader: WebGLShader;

  constructor(type: number, source: string) {
    this.shader = gl.createShader(type);
    gl.shaderSource(this.shader, source);
    gl.compileShader(this.shader);

    if (!gl.getShaderParameter(this.shader, gl.COMPILE_STATUS)) {
      throw gl.getShaderInfoLog(this.shader);
    }
  }
};

class ShaderProgram {
  prog: WebGLProgram;

  attrPos: number;
  attrNor: number;

  unifRef: WebGLUniformLocation;
  unifEye: WebGLUniformLocation;
  unifUp: WebGLUniformLocation;
  unifDimensions: WebGLUniformLocation;
  unifTime: WebGLUniformLocation;
  unifAnim : WebGLUniformLocation; // Added for HW2
  unifColors : WebGLUniformLocation; // Added for HW2
  unifSpeed : WebGLUniformLocation; // Added for HW2
  unifBombOffset : WebGLUniformLocation; // Added for HW2

  constructor(shaders: Array<Shader>) {
    this.prog = gl.createProgram();

    for (let shader of shaders) {
      gl.attachShader(this.prog, shader.shader);
    }
    gl.linkProgram(this.prog);
    if (!gl.getProgramParameter(this.prog, gl.LINK_STATUS)) {
      throw gl.getProgramInfoLog(this.prog);
    }

    this.attrPos = gl.getAttribLocation(this.prog, "vs_Pos");
    this.unifEye   = gl.getUniformLocation(this.prog, "u_Eye");
    this.unifRef   = gl.getUniformLocation(this.prog, "u_Ref");
    this.unifUp   = gl.getUniformLocation(this.prog, "u_Up");
    this.unifDimensions   = gl.getUniformLocation(this.prog, "u_Dimensions");
    this.unifTime   = gl.getUniformLocation(this.prog, "u_Time");
    this.unifAnim   = gl.getUniformLocation(this.prog, "u_Anim"); // Added for HW2
    this.unifColors   = gl.getUniformLocation(this.prog, "u_ColorsOn"); // Added for HW2
    this.unifSpeed   = gl.getUniformLocation(this.prog, "u_Speed"); // Added for HW2
    this.unifBombOffset   = gl.getUniformLocation(this.prog, "u_BombOffset"); // Added for HW2
  }

  use() {
    if (activeProgram !== this.prog) {
      gl.useProgram(this.prog);
      activeProgram = this.prog;
    }
  }

  setEyeRefUp(eye: vec3, ref: vec3, up: vec3) {
    this.use();
    if(this.unifEye !== -1) {
      gl.uniform3f(this.unifEye, eye[0], eye[1], eye[2]);
    }
    if(this.unifRef !== -1) {
      gl.uniform3f(this.unifRef, ref[0], ref[1], ref[2]);
    }
    if(this.unifUp !== -1) {
      gl.uniform3f(this.unifUp, up[0], up[1], up[2]);
    }
  }

  setDimensions(width: number, height: number) {
    this.use();
    if(this.unifDimensions !== -1) {
      gl.uniform2f(this.unifDimensions, width, height);
    }
  }

  // Added for HW2
  setUAnim(t: number) {
    this.use();
    if(this.unifAnim !== -1) {
      gl.uniform1f(this.unifAnim, t);
    }
  }

  // Added for HW2
  setUColorsOn(t: number) {
    this.use();
    if(this.unifColors !== -1) {
      gl.uniform1f(this.unifColors, t);
    }
  }

  // Added for HW2
  setUSpeed(t: number) {
    this.use();
    if(this.unifSpeed !== -1) {
      gl.uniform1f(this.unifSpeed, t);
    }
  }

  // Added for Hw2
  setBombOffset(x : number, y : number, z : number){
    this.use();
    if(this.unifBombOffset !== -1){
      gl.uniform3f(this.unifBombOffset, x, y, z);
    }
  }

  setTime(t: number) {
    this.use();
    if(this.unifTime !== -1) {
      gl.uniform1f(this.unifTime, t);
    }
  }

  draw(d: Drawable) {
    this.use();

    if (this.attrPos != -1 && d.bindPos()) {
      gl.enableVertexAttribArray(this.attrPos);
      gl.vertexAttribPointer(this.attrPos, 4, gl.FLOAT, false, 0, 0);
    }

    d.bindIdx();
    gl.drawElements(d.drawMode(), d.elemCount(), gl.UNSIGNED_INT, 0);

    if (this.attrPos != -1) gl.disableVertexAttribArray(this.attrPos);
  }
};

export default ShaderProgram;
