import React, { useEffect, useMemo, useState, useRef, Suspense } from 'react';
import * as THREE from 'three';
import { extend, Canvas, useFrame, useLoader, useThree } from '@react-three/fiber'
import circleImg from "../assets/circle.png";
import { shaderMaterial } from '@react-three/drei';
import Delaunator from 'delaunator';

import {
    Bounds,
    useBounds,
    OrbitControls,
    ContactShadows,
    useGLTF,
    Points,
    PointMaterial
} from '@react-three/drei'

const ColorDistanceShaderMaterial = shaderMaterial(
  // Uniforms
  {
    colorWhite: new THREE.Color(0xffffff), // White
    //colorBlue: new THREE.Color(0x0000ff),  // Blue
    //colorPurple: new THREE.Color(0x800080),// Purple

    colorBlue: new THREE.Color(0x05FFBF),  // Blue
    colorPurple: new THREE.Color(0xffffff),// Purple

    customCameraPos: new THREE.Vector3(),
      pointSize: 3.0, // Uniform for controlling point size

  },
  // Vertex Shader
  `
    varying vec3 vPosition;
    uniform float pointSize; // Point size uniform


    void main() {
      vPosition = position;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      gl_PointSize = pointSize;
    }
  `,
  // Fragment Shader
  `
    uniform vec3 colorWhite;
    uniform vec3 colorBlue;
    uniform vec3 colorPurple;
    uniform vec3 customCameraPos;
    varying vec3 vPosition;

    void main() {
      float distance = length(customCameraPos - vPosition);
      vec3 colorIntermediate = mix(colorWhite, colorBlue, clamp(distance / 90.0, 0.0, 1.0)); // First interpolate from white to blue
      vec3 colorFinal = mix(colorIntermediate, colorPurple, clamp((distance - 90.0) / 90.0, 0.0, 1.0)); // Then from the result to purple
      gl_FragColor = vec4(colorFinal, 1.0);
    }
  `
);

extend({ ColorDistanceShaderMaterial });


const PointCloudRenderer = ({ vertices }) => {

    const CircleImg = useLoader(THREE.TextureLoader, circleImg);

    const materialRef = useRef();

    // #############
    // load from file
    // #############

    const loadVertices = () => {
        let positions = [];
        import("../assets/pointcloudtest_1.json").then(arr => {
            for (let i = 0; i < arr.length; i++) {
                const [x, y, z] = arr[i];
                positions.push(x, y, z);
            }
            positions = positions.map((x) => x * 100);
            let v = new Float32Array(positions);
            setVertices(v);
        });
    }

    useEffect(() => {
        const ws = new WebSocket('ws://localhost:8000/ws/get_data');
        //const ws = new WebSocket("wss://a109-171-64-77-61.ngrok-free.app/ws/send_data");


        ws.addEventListener("open", (event) => {
            ws.send("Connection established")
        })

        ws.addEventListener("message", (event) => {
            //console.log("Message from server", event.data)
            // expect to receive a Float32Array
            //console.log(event.data)
            // the event.data is a string of json which is {"float_array": [0.0, 0.0, 0.0, ...]}

            let arr = JSON.parse(event.data).float_array;

            // flip the x and y axes
            for (let i = 0; i < arr.length; i += 3) {
                let x = arr[i];
                arr[i] = arr[i + 1];
                arr[i + 1] = -x;
            }

            // for every single point, add another n points with the same x and y and z but slightly offset

            //const DUPLICATION_NUM = 10;
            //let new_arr = [];

            //for (let i = 0; i < arr.length; i += 3) {
            //    for (let j = 0; j < DUPLICATION_NUM; j++) {
            //        new_arr.push(arr[i] + Math.random() * 2);
            //        new_arr.push(arr[i + 1] + Math.random() * 2);
            //        new_arr.push(arr[i + 2] + Math.random() * 2);
            //    }
            //}


            //let v = new Float32Array(new_arr);
            let v = new Float32Array(arr);
            setVertices(v);
            setKey(prevKey => prevKey + 1);
        })

        return () => {
            ws.close();
        }
    }, []);


    useEffect(() => {
        let v = loadVertices();
    }, []);

    // #######################
    // test vertices
    // #######################
    const NUM_POINTS = 1000*100000;
    const generateVertices = () => {
        let positions = [];
        for (let xi = 0; xi <(Math.random() * NUM_POINTS); xi++) {
            const [x, y, z] = [Math.random() * 100, Math.random() * 100, Math.random() * 100];
            positions.push(x, y, z);
        }
        return new Float32Array(positions);
    };
    //const [test_vertices, setVertices] = useState(generateVertices());

    //useEffect(() => {
    //    const interval = setInterval(() => {

    //        const verts = generateVertices();
    //        setVertices(verts);

    //        setKey(prevKey => prevKey + 1);

    //        console.log('vertices updated');
    //    }, 1000);
    //    return () => clearInterval(interval);
    //}, []);
    // #######################

    const [test_vertices, setVertices] = useState(generateVertices());

    const [key, setKey] = useState(0);
    const positionRef = useRef();

    useEffect(() => {
        if (positionRef.current) {
            positionRef.current.needsUpdate = true;
            setKey(prevKey => prevKey + 1);
        }
    }, [test_vertices]);


    //const geometry = new THREE.BufferGeometry();
    //geometry.setFromPoints(test_vertices.map(([x, y, z]) => new THREE.Vector3(x, y, z)));
    //geometry.computeVertexNormals();
    //const material = new THREE.MeshStandardMaterial({ color: 0x00ff00, wireframe: true });

    //const mesh = new THREE.Mesh(geometry, material);








//#################################
    //const generateMesh = () => {
    //    const vertices = test_vertices
    //    const vectorVertices = [];

    //    for (let i = 0; i < vertices.length; i += 3) {
    //        vectorVertices.push(new THREE.Vector3(vertices[i], vertices[i + 1], vertices[i + 2]));
    //    }
    //    const geometry = new THREE.BufferGeometry();
    //    const float32Array = new Float32Array(vertices); // Ensure it's a Float32Array
    //    geometry.setAttribute('position', new THREE.BufferAttribute(float32Array, 3));
    //    geometry.computeVertexNormals();

    //    const material = new THREE.MeshStandardMaterial({ color: 0x00ff00, wireframe: true }); // Example: Green wireframe material
    //    const mesh = new THREE.Mesh(geometry, material);

    //    return mesh
    //}

    //const mesh = useMemo(() => generateMesh(), [test_vertices]);
//#################################

    // triangulate x, z
    //var indexDelaunay = Delaunator.from(
    //    points3d.map(v => {
    //        return [v.x, v.z];
    //    })
    //);

    // made the flattened array of vertices into an array of tuples
    //var geom = new THREE.BufferGeometry().setFromPoints(points3d);

    //const generateMesh = () => {

    //    // randomly sample n points from the test_vertices
    //    let n = 900;
    //    let sample = [];
    //    for (let i = 0; i < n; i++) {
    //        let idx = Math.floor(Math.random() * test_vertices.length / 3);
    //        sample.push(test_vertices[idx * 3], test_vertices[idx * 3 + 1], test_vertices[idx * 3 + 2]);
    //    }

    //    //let sample = test_vertices;

    //    let points3d = [];
    //    for (let i = 0; i < sample.length; i += 3) {
    //        points3d.push(new THREE.Vector3(sample[i], sample[i + 1], sample[i + 2]));
    //    }

    //    // filter out all the poitns with z > 10
    //    //points3d = points3d.filter((v) => v.z < 200);
    //    //console.log(points3d.length, "here");

    //    //var geom = new THREE.BufferGeometry() // TODO
    //    var geom = new THREE.BufferGeometry().setFromPoints(points3d);

    //    let indexDelaunay = Delaunator.from(
    //        // test vertices is a flattened map of x, y, z
    //        // we need to convert it to tuples of just [x, z]
    //        sample.reduce((acc, cur, i) => {
    //            if (i % 3 === 0) {
    //                acc.push([cur, sample[i + 2]]);
    //            }
    //            return acc;
    //        }, [])
    //    );

    //    // filter out all the triangles with long edges
    //    //indexDelaunay.triangles = indexDelaunay.triangles.filter((i) => i < 200000);

    //    //console.log('indexDelaunay:', indexDelaunay.triangles);

    //    var meshIndex = []; // delaunay index => three.js index
    //    for (let i = 0; i < indexDelaunay.triangles.length; i++){
    //        meshIndex.push(indexDelaunay.triangles[i]);
    //    }

    //    // i want to remove all the triangles with long edges

    //    let newMeshIndex = [];
    //    const MAX_EDGE_LENGTH = 10;
    //    for (let i = 0; i < meshIndex.length; i += 3) {
    //        let [a, b, c] = [meshIndex[i], meshIndex[i + 1], meshIndex[i + 2]];
    //        let [v1, v2, v3] = [points3d[a], points3d[b], points3d[c]];
    //        let [l1, l2, l3] = [v1.distanceTo(v2), v2.distanceTo(v3), v3.distanceTo(v1)];
    //        if (l1 < MAX_EDGE_LENGTH && l2 < MAX_EDGE_LENGTH && l3 < MAX_EDGE_LENGTH) {
    //            newMeshIndex.push(a, b, c);
    //        }
    //    }

    //    //geom.setIndex(meshIndex); // add three.js index to the existing geometry
    //    geom.setIndex(newMeshIndex); // add three.js index to the existing geometry

    //    geom.computeVertexNormals();
    //    var mesh = new THREE.Mesh(
    //        geom, // re-use the existing geometry
    //        new THREE.MeshLambertMaterial({ color: "#53F6FF", wireframe: true, opacity: 0.2, transparent: true })
    //    );
    //    return mesh;
    //}

    //const mesh = useMemo(() => generateMesh(), [test_vertices]);

    return (
        <>
      <Canvas
        style={{
          backgroundColor: '#0B0B0B',
          //backgroundColor: 'black',
        }}
      >
                <Bounds fit clip observe margin={1.2}>
                    <points key={key}>
                        <bufferGeometry attach="geometry">
                            <bufferAttribute
                                ref={positionRef}
                                attach="attributes-position"
                                array={test_vertices}
                                count={test_vertices.length / 3}
                                itemSize={3}
                            />
                        </bufferGeometry>
                        <colorDistanceShaderMaterial ref={materialRef} attach="material" 
                            pointSize={2}
                        />
                    </points>

                    {/*render the mesh from above called called mesh*/}
                    {/*<primitive object={mesh} key={key+1}/>*/}
                          {/*<meshStandardMaterial color={0x00ff00} wireframe={true} />*/}




                    <SelectToZoom>
                        <Box position={[-1.2, 0, 0]} />
                        <Box position={[1.2, 0, 0]} />
                    </SelectToZoom>
                </Bounds>

                <ambientLight intensity={Math.PI / 2} />
              <OrbitControls makeDefault minPolarAngle={0}  />
      </Canvas>
        </>

    )

}

export default PointCloudRenderer;

function Box(props) {
    // This reference will give us direct access to the mesh
    const meshRef = useRef()
    // Set up state for the hovered and active state
    const [hovered, setHover] = useState(false)
    const [active, setActive] = useState(false)
    // Subscribe this component to the render-loop, rotate the mesh every frame
    useFrame((state, delta) => (meshRef.current.rotation.x += delta))
    // Return view, these are regular three.js elements expressed in JSX
    return (
        <mesh
            {...props}
            ref={meshRef}
            scale={active ? 1.5 : 1}
            onClick={(event) => setActive(!active)}
            onPointerOver={(event) => setHover(true)}
            onPointerOut={(event) => setHover(false)}>
            <boxGeometry args={[1, 1, 1]} />
            <meshStandardMaterial color={hovered ? 'hotpink' : 'orange'} />
        </mesh>
    )
}

function SelectToZoom({ children }) {
    const api = useBounds()
    return (
        <group onClick={(e) => (e.stopPropagation(), e.delta <= 2 && api.refresh(e.object).fit())} onPointerMissed={(e) => e.button === 0 && api.refresh().fit()}>
            {children}
        </group>
    )
}

function RotatedCamera() {
    const { camera } = useThree(); // Access the Three.js camera from the context

    useEffect(() => {
        // Rotate the camera 90 degrees around the Z-axis
        camera.rotation.z = Math.PI /2; // 90 degrees in radians
        camera.updateProjectionMatrix(); // Important to update the camera after changing its properties
    }, [camera]);

    return null; // This component doesn't render anything itself
}

