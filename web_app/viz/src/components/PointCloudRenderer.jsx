import React, { useEffect, useMemo, useState, useRef, Suspense } from 'react';
import {  } from '@react-three/drei';
import * as THREE from 'three';
import { Canvas, useFrame } from '@react-three/fiber'
import { 
    Bounds,
    useBounds,
    OrbitControls,
    ContactShadows,
    useGLTF,
    Points,
    PointMaterial
} from '@react-three/drei'


const PointCloudRenderer = () => {

    const NUM_POINTS = 1000*10000;
    const generateVertices = () => {
        let positions = [];
        for (let xi = 0; xi <(Math.random() * NUM_POINTS); xi++) {
            const [x, y, z] = [Math.random() * 100, Math.random() * 100, Math.random() * 100];
            positions.push(x, y, z);
        }
        return new Float32Array(positions);
    };

    const [test_vertices, setVertices] = useState(generateVertices());
    const [key, setKey] = useState(0);
    const positionRef = useRef();

    useEffect(() => {
        const interval = setInterval(() => {

            const verts = generateVertices();
            setVertices(verts);

            setKey(prevKey => prevKey + 1);

            console.log('vertices updated');
        }, 100);
        return () => clearInterval(interval);
    }, []);

    useEffect(() => {
        if (positionRef.current) {
            positionRef.current.needsUpdate = true;
        }
    }, [test_vertices]);

    return (
        <div
            className="h-screen border-0"
        >

            <Canvas>
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
                        {/*<pointsMaterial
                            attach="material"
                            map={CircleImg}
                            color={0x00aaff}
                            sizes={0.5}
                            sizeAttenuation //merupakan parameter yang menscale object berdasarkan perspective camera
                            transparent={false}
                            alphaTest={0.5} //merupakan thresshold saat rendering untuk mencega bila opacity dibawah value alphatest
                            opacity={1.0}
                        />*/}
                    </points>
                    <SelectToZoom>
                        <Box position={[-1.2, 0, 0]} />
                        <Box position={[1.2, 0, 0]} />
                    </SelectToZoom>
                </Bounds>

                <ambientLight intensity={Math.PI / 2} />
              <OrbitControls makeDefault minPolarAngle={0} maxPolarAngle={Math.PI / 1.75} />
            </Canvas>
        </div>
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

