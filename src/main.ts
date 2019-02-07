import {vec2, vec3} from 'gl-matrix';
import * as Stats from 'stats-js';
import * as DAT from 'dat-gui';
import Square from './geometry/Square';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations: 5,
  'Animate Scene': false, // Added for HW 2
  'Animate Colors' : false, // added
  Speed: 1.0, // Added for HW2
  BombXPos: 0.0, // added
  BombYPos: 0.0, // added
  BombZPos: 0.0, // added
  'Load Scene': loadScene, // A function pointer, essentially
};

let square: Square;
let time: number = 0;

function loadScene() {
  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();
  // time = 0;
}

function main() {
  window.addEventListener('keypress', function (e) {
    // console.log(e.key);
    switch(e.key) {
      // Use this if you wish
    }
  }, false);

  window.addEventListener('keyup', function (e) {
    switch(e.key) {
      // Use this if you wish
    }
  }, false);

  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  const gui = new DAT.GUI();

  gui.add(controls, 'Animate Scene'); // Added for HW2
  gui.add(controls, 'Animate Colors'); // Added for HW2
  gui.add(controls, 'Speed', 1.0, 10.0).step(1.0); // Added for HW2
  gui.add(controls, 'BombXPos', -15.0, 15.0).step(1.0); // Added for HW2
  gui.add(controls, 'BombYPos', -15.0, 15.0).step(1.0); // Added for HW2
  gui.add(controls, 'BombZPos', -15.0, 15.0).step(1.0); // Added for HW2

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene
  loadScene();

  const camera = new Camera(vec3.fromValues(0, 0, -10), vec3.fromValues(0, 0, 0));

  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(164.0 / 255.0, 233.0 / 255.0, 1.0, 1);
  gl.enable(gl.DEPTH_TEST);

  const flat = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/flat-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/flat-frag.glsl')),
  ]);

  function processKeyPresses() {
    // Use this if you wish
  }

  // This function will be called every frame
  function tick() {
    camera.update();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();
    processKeyPresses();

    // Added for HW2
    if(controls["Animate Colors"] == true){
      flat.setUColorsOn(1.0);
    }
    else{
      flat.setUColorsOn(0.0);
    }
    if(controls["Animate Scene"] == true){
      // set value to 1
      flat.setUAnim(1.0);
      flat.setUSpeed(controls.Speed);
    }
    else{
      // set value to 0
      flat.setUAnim(0.0);
      flat.setUSpeed(1.0);
    }

    // passing slider info - Added for HW2
    flat.setBombOffset(controls.BombXPos, controls.BombYPos, controls.BombZPos);

    renderer.render(camera, flat, [
      square,
    ], time);
    time++;
    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
    flat.setDimensions(window.innerWidth, window.innerHeight);
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();
  flat.setDimensions(window.innerWidth, window.innerHeight);

  // Start the render loop
  tick();
}

main();
