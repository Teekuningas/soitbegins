module World.World exposing
    ( axisMesh
    , axisUnif
    , earthUnif
    , fireMesh
    , fireUnif
    , fragmentShader
    , heroMesh
    , heroUnif
    , sunMesh
    , sunUnif
    , vertexShader
    )

import HUD.Types exposing (CanvasDimensions)
import Math.Matrix4 as Mat4 exposing (Mat4)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import WebGL exposing (Mesh, Shader)
import World.Types exposing (Camera, Earth, Hero, MeshList, Uniforms, Vertex)


generalUnif : Bool -> CanvasDimensions -> Earth -> Hero -> Camera -> Uniforms
generalUnif overviewToggle canvasDim earth hero camera =
    let
        aspect =
            toFloat canvasDim.width
                / toFloat canvasDim.height

        cameraMat =
            if overviewToggle == True then
                makeOverviewCamera canvasDim earth hero

            else
                makeHeroCamera canvasDim earth hero camera
    in
    { preScale =
        Mat4.identity
    , preRotation =
        Mat4.identity
    , preTranslation =
        Mat4.identity
    , scale =
        Mat4.identity
    , rotation =
        Mat4.identity
    , translation =
        Mat4.identity
    , postScale =
        Mat4.identity
    , postRotation =
        Mat4.identity
    , postTranslation =
        Mat4.identity
    , perspective =
        Mat4.makePerspective 45 aspect 1 10000
    , camera =
        cameraMat
    , shade = 0.75
    }


sunUnif : Bool -> CanvasDimensions -> Earth -> Hero -> Camera -> Uniforms
sunUnif overviewToggle canvasDim earth hero camera =
    let
        unif =
            generalUnif overviewToggle canvasDim earth hero camera

        -- Sun lies at the origin but is scaled
        scale =
            Mat4.scale (vec3 200 200 200) Mat4.identity
    in
    { unif | scale = scale }


earthUnif : Bool -> CanvasDimensions -> Earth -> Hero -> Camera -> Uniforms
earthUnif overviewToggle canvasDim earth hero camera =
    let
        unif =
            generalUnif overviewToggle canvasDim earth hero camera

        -- The earth mesh comes in wrong position so fix here..
        preScale =
            Mat4.makeRotate (pi / 2) (vec3 1 0 0)

        -- Scale the earth.
        -- I first tried to keep earth as size 1 and decrease
        -- size of the balloon. However, that leads to inaccuracies
        -- in rendering the balloon.
        scale =
            Mat4.scale (vec3 100 100 100) Mat4.identity

        -- Tilt and rotate along the correct axis
        rotation =
            Mat4.mul
                (Mat4.makeRotate ((23.5 / 180) * pi) (vec3 0 0 1))
                (Mat4.makeRotate earth.rotationAroundAxis (vec3 0 1 0))

        earthLocationX =
            1000 * (cos earth.rotationAroundSun + sin earth.rotationAroundSun)

        earthLocationY =
            0

        earthLocationZ =
            1000 * (cos earth.rotationAroundSun - sin earth.rotationAroundSun)

        -- Move to the correct location
        translation =
            Mat4.translate
                (vec3 earthLocationX
                    earthLocationY
                    earthLocationZ
                )
                Mat4.identity
    in
    { unif
        | preScale = preScale
        , rotation = rotation
        , translation = translation
        , scale = scale
    }


axisUnif : Bool -> CanvasDimensions -> Earth -> Hero -> Camera -> Uniforms
axisUnif overviewToggle canvasDim earth hero camera =
    let
        unif =
            earthUnif overviewToggle canvasDim earth hero camera
    in
    { unif | preScale = Mat4.identity }


heroUnif : Bool -> CanvasDimensions -> Earth -> Hero -> Camera -> Uniforms
heroUnif overviewToggle canvasDim earth hero camera =
    let
        unif =
            generalUnif overviewToggle canvasDim earth hero camera

        -- Hero size
        scale =
            Mat4.scale (vec3 0.1 0.1 0.1) Mat4.identity

        -- Hero wiggling
        rotation =
            Mat4.mul (Mat4.makeRotate (3 * hero.rotationTheta) (vec3 0 1 0))
                (Mat4.makeRotate (2 * hero.rotationTheta) (vec3 1 0 0))

        -- Hero moved directly up from hero origin
        translation =
            Mat4.translate (Vec3.scale hero.altitude Vec3.j) Mat4.identity

        -- Hero rotated along different axis in the origin, effectively
        -- translating hero to correct position in a correct orientation
        earthAxis =
            Mat4.transform
                (Mat4.makeRotate ((23.5 / 180) * pi) (vec3 0 0 1))
                Vec3.j

        latitudeAxis =
            Vec3.cross earthAxis (vec3 1 0 0)

        alignRotation =
            Mat4.makeRotate ((23.5 / 180) * pi) (vec3 0 0 1)

        latitudeRotation =
            Mat4.makeRotate (pi / 2 - hero.latitude) latitudeAxis

        longitudeRotation =
            Mat4.makeRotate hero.longitude earthAxis

        earthRotationRotation =
            Mat4.makeRotate earth.rotationAroundAxis earthAxis

        postRotation =
            List.foldl
                Mat4.mul
                Mat4.identity
                [ alignRotation
                , latitudeRotation
                , longitudeRotation
                , earthRotationRotation
                ]

        earthLocationX =
            1000 * (cos earth.rotationAroundSun + sin earth.rotationAroundSun)

        earthLocationY =
            0

        earthLocationZ =
            1000 * (cos earth.rotationAroundSun - sin earth.rotationAroundSun)

        -- And finally moved to the earth
        postTranslation =
            Mat4.translate
                (vec3 earthLocationX
                    earthLocationY
                    earthLocationZ
                )
                Mat4.identity
    in
    { unif
        | scale = scale
        , rotation = rotation
        , translation = translation
        , postRotation = postRotation
        , postTranslation = postTranslation
    }


fireUnif : Bool -> CanvasDimensions -> Earth -> Hero -> Camera -> Uniforms
fireUnif overviewToggle canvasDim earth hero camera =
    let
        unif =
            heroUnif overviewToggle canvasDim earth hero camera

        -- The power source fire is approximately where the hero origin is
        -- but we move and scale it in the hero space to the exact
        -- correct location.
        preScale =
            Mat4.scale
                (vec3 (hero.power / 2)
                    (hero.power / 2)
                    (hero.power / 2)
                )
                Mat4.identity

        preTranslation =
            Mat4.translate (vec3 0 1.7 0) Mat4.identity
    in
    { unif
        | preScale = preScale
        , preTranslation = preTranslation
    }


axisMesh : Mesh Vertex
axisMesh =
    let
        axisColor =
            Vec3.scale (1 / 255) (vec3 204 0 0)

        -- red
    in
    [ meshPositionMap (Vec3.add (vec3 0 1.25 0))
        (meshPositionMap (Vec3.scale 0.05) (icosaMeshList axisColor))
    , meshPositionMap (Vec3.add (vec3 0 1.5 0))
        (meshPositionMap (Vec3.scale 0.05) (icosaMeshList axisColor))
    , meshPositionMap (Vec3.add (vec3 0 1.75 0))
        (meshPositionMap (Vec3.scale 0.05) (icosaMeshList axisColor))
    , meshPositionMap (Vec3.add (vec3 0 2.0 0))
        (meshPositionMap (Vec3.scale 0.05) (icosaMeshList axisColor))
    , meshPositionMap (Vec3.add (vec3 0 -1.25 0))
        (meshPositionMap (Vec3.scale 0.05) (icosaMeshList axisColor))
    , meshPositionMap (Vec3.add (vec3 0 -1.5 0))
        (meshPositionMap (Vec3.scale 0.05) (icosaMeshList axisColor))
    , meshPositionMap (Vec3.add (vec3 0 -1.75 0))
        (meshPositionMap (Vec3.scale 0.05) (icosaMeshList axisColor))
    , meshPositionMap (Vec3.add (vec3 0 -2.0 0))
        (meshPositionMap (Vec3.scale 0.05) (icosaMeshList axisColor))
    ]
        |> List.concat
        |> WebGL.triangles


sunMesh : Mesh Vertex
sunMesh =
    let
        sunColor =
            Vec3.scale (1 / 255) (vec3 237 212 0)

        -- yellow
    in
    icosaMeshList sunColor
        |> subdivideProject sunColor
        |> subdivideProject sunColor
        |> WebGL.triangles


fireMesh : Mesh Vertex
fireMesh =
    let
        fireColor =
            Vec3.scale (1 / 255) (vec3 245 121 0)

        -- orange
    in
    [ icosaMeshList fireColor
    ]
        |> List.concat
        |> WebGL.triangles


heroMesh : Vec3 -> Mesh Vertex
heroMesh envelopeColor =
    let
        basketColor =
            Vec3.scale (1 / 255) (vec3 133 87 35)

        burnerColor =
            Vec3.scale (1 / 255) (vec3 113 121 126)
    in
    [ basketMeshList basketColor
    , envelopeMeshList envelopeColor
    , burnerMeshList burnerColor
    ]
        |> List.concat
        |> WebGL.triangles


burnerMeshList : Vec3 -> MeshList
burnerMeshList color =
    let
        rft =
            vec3 1 1 1

        lft =
            vec3 -1 1 1

        lbt =
            vec3 -1 1 -1

        rbt =
            vec3 1 1 -1

        rbb =
            vec3 1 -1 -1

        rfb =
            vec3 1 -1 1

        lfb =
            vec3 -1 -1 1

        lbb =
            vec3 -1 -1 -1

        meshList =
            [ face color rft rfb rbb rbt
            , face color lft lfb rfb rft
            , face color rbt lbt lft rft
            , face color rfb lfb lbb rbb
            , face color lbt lbb lfb lft
            , face color rbt rbb lbb lbt
            ]
    in
    meshList
        |> List.concat
        |> meshPositionMap (Vec3.scale 0.5)
        |> meshPositionMap (Vec3.add (vec3 0 0.7 0))


envelopeMeshList : Vec3 -> MeshList
envelopeMeshList envelopeColor =
    meshPositionMap
        (Vec3.add (vec3 0 7.5 0))
        (meshPositionMap
            (Vec3.scale 5)
            (subdivideProject envelopeColor (icosaMeshList envelopeColor))
        )


basketMeshList : Vec3 -> MeshList
basketMeshList color =
    let
        rft =
            vec3 1 1 1

        lft =
            vec3 -1 1 1

        lbt =
            vec3 -1 1 -1

        rbt =
            vec3 1 1 -1

        rbb =
            vec3 1 -1 -1

        rfb =
            vec3 1 -1 1

        lfb =
            vec3 -1 -1 1

        lbb =
            vec3 -1 -1 -1

        meshList =
            [ face color rft rfb rbb rbt
            , face color lft lfb rfb rft
            , face color rbt lbt lft rft
            , face color rfb lfb lbb rbb
            , face color lbt lbb lfb lft
            , face color rbt rbb lbb lbt
            ]
    in
    meshList
        |> List.concat
        |> meshPositionMap (Vec3.add (vec3 0 -1.5 0))


face : Vec3 -> Vec3 -> Vec3 -> Vec3 -> Vec3 -> MeshList
face color a b c d =
    let
        vertex position =
            Vertex color position
    in
    [ ( vertex a, vertex b, vertex c )
    , ( vertex c, vertex d, vertex a )
    ]


icosaMeshList : Vec3 -> MeshList
icosaMeshList clr =
    let
        phi =
            (1.0 + sqrt 5.0) * 0.5

        a =
            1.0

        b =
            1.0 / phi

        v1 =
            Vertex (Vec3.add clr (vec3 0.0 0.0 0.0)) (Vec3.normalize (vec3 0 b -a))

        v2 =
            Vertex (Vec3.add clr (vec3 0.02 0.02 0.02)) (Vec3.normalize (vec3 b a 0))

        v3 =
            Vertex (Vec3.add clr (vec3 0.04 0.04 0.04)) (Vec3.normalize (vec3 -b a 0))

        v4 =
            Vertex (Vec3.add clr (vec3 0.06 0.06 0.06)) (Vec3.normalize (vec3 0 b a))

        v5 =
            Vertex (Vec3.add clr (vec3 0.08 0.08 0.08)) (Vec3.normalize (vec3 0 -b a))

        v6 =
            Vertex (Vec3.add clr (vec3 0.1 0.1 0.1)) (Vec3.normalize (vec3 -a 0 b))

        v7 =
            Vertex (Vec3.add clr (vec3 0.12 0.12 0.12)) (Vec3.normalize (vec3 0 -b -a))

        v8 =
            Vertex (Vec3.add clr (vec3 0.14 0.14 0.14)) (Vec3.normalize (vec3 a 0 -b))

        v9 =
            Vertex (Vec3.add clr (vec3 0.16 0.16 0.16)) (Vec3.normalize (vec3 a 0 b))

        v10 =
            Vertex (Vec3.add clr (vec3 0.18 0.18 0.18)) (Vec3.normalize (vec3 -a 0 -b))

        v11 =
            Vertex (Vec3.add clr (vec3 0.2 0.2 0.2)) (Vec3.normalize (vec3 b -a 0))

        v12 =
            Vertex (Vec3.add clr (vec3 0.22 0.22 0.22)) (Vec3.normalize (vec3 -b -a 0))
    in
    [ ( v3, v2, v1 )
    , ( v2, v3, v4 )
    , ( v6, v5, v4 )
    , ( v5, v9, v4 )
    , ( v8, v7, v1 )
    , ( v7, v10, v1 )
    , ( v12, v11, v5 )
    , ( v11, v12, v7 )
    , ( v10, v6, v3 )
    , ( v6, v10, v12 )
    , ( v9, v8, v2 )
    , ( v8, v9, v11 )
    , ( v3, v6, v4 )
    , ( v9, v2, v4 )
    , ( v10, v3, v1 )
    , ( v2, v8, v1 )
    , ( v12, v10, v7 )
    , ( v8, v11, v7 )
    , ( v6, v12, v5 )
    , ( v11, v9, v5 )
    ]


subdivideProject : Vec3 -> MeshList -> MeshList
subdivideProject clr mesh =
    let
        helper m =
            case m of
                [] ->
                    []

                ( v1, v2, v3 ) :: xs ->
                    let
                        mp12X =
                            (Vec3.getX v1.position
                                + Vec3.getX v2.position
                            )
                                / 2

                        mp12Y =
                            (Vec3.getY v1.position
                                + Vec3.getY v2.position
                            )
                                / 2

                        mp12Z =
                            (Vec3.getZ v1.position
                                + Vec3.getZ v2.position
                            )
                                / 2

                        mp13X =
                            (Vec3.getX v1.position
                                + Vec3.getX v3.position
                            )
                                / 2

                        mp13Y =
                            (Vec3.getY v1.position
                                + Vec3.getY v3.position
                            )
                                / 2

                        mp13Z =
                            (Vec3.getZ v1.position
                                + Vec3.getZ v3.position
                            )
                                / 2

                        mp23X =
                            (Vec3.getX v2.position
                                + Vec3.getX v3.position
                            )
                                / 2

                        mp23Y =
                            (Vec3.getY v2.position
                                + Vec3.getY v3.position
                            )
                                / 2

                        mp23Z =
                            (Vec3.getZ v2.position
                                + Vec3.getZ v3.position
                            )
                                / 2

                        clr12 =
                            clr

                        clr13 =
                            clr

                        clr23 =
                            clr

                        pos12 =
                            vec3 mp12X mp12Y mp12Z

                        pos13 =
                            vec3 mp13X mp13Y mp13Z

                        pos23 =
                            vec3 mp23X mp23Y mp23Z

                        v12 =
                            Vertex clr12 (Vec3.normalize pos12)

                        v13 =
                            Vertex clr13 (Vec3.normalize pos13)

                        v23 =
                            Vertex clr23 (Vec3.normalize pos23)
                    in
                    [ ( v1, v12, v13 )
                    , ( v12, v2, v23 )
                    , ( v23, v3, v13 )
                    , ( v13, v12, v23 )
                    ]
                        :: helper xs
    in
    List.concat (helper mesh)


makeOverviewCamera : CanvasDimensions -> Earth -> Hero -> Mat4
makeOverviewCamera canvasDim earth hero =
    let
        sunLocationX =
            0

        sunLocationY =
            0

        sunLocationZ =
            0
    in
    Mat4.makeLookAt (vec3 0 0 -4000)
        (vec3 sunLocationX
            sunLocationY
            sunLocationZ
        )
        (vec3 0 1 0)


makeHeroCamera : CanvasDimensions -> Earth -> Hero -> Camera -> Mat4
makeHeroCamera canvasDim earth hero camera =
    let
        azimoth =
            camera.azimoth

        elevation =
            camera.elevation

        earthLocationX =
            1000 * (cos earth.rotationAroundSun + sin earth.rotationAroundSun)

        earthLocationY =
            0

        earthLocationZ =
            1000 * (cos earth.rotationAroundSun - sin earth.rotationAroundSun)

        earthLoc =
            vec3 earthLocationX
                earthLocationY
                earthLocationZ

        -- Generate a general rotation matrix that can transform
        -- the hero, the camera and even the up vector.
        earthAxis =
            Mat4.transform
                (Mat4.makeRotate ((23.5 / 180) * pi) (vec3 0 0 1))
                Vec3.j

        latitudeAxis =
            Vec3.cross earthAxis (vec3 1 0 0)

        alignRotation =
            Mat4.makeRotate ((23.5 / 180) * pi) (vec3 0 0 1)

        latitudeRotation =
            Mat4.makeRotate (pi / 2 - hero.latitude) latitudeAxis

        longitudeRotation =
            Mat4.makeRotate hero.longitude earthAxis

        earthRotationRotation =
            Mat4.makeRotate earth.rotationAroundAxis earthAxis

        rotateAround =
            List.foldl
                Mat4.mul
                Mat4.identity
                [ alignRotation
                , latitudeRotation
                , longitudeRotation
                , earthRotationRotation
                ]

        -- Find out the target location
        targetTransformation =
            List.foldl
                Mat4.mul
                Mat4.identity
                [ Mat4.translate (vec3 0 hero.altitude 0) Mat4.identity
                , rotateAround
                , Mat4.translate earthLoc Mat4.identity
                ]

        targetLocation =
            Mat4.transform targetTransformation (vec3 0 0 0)

        -- Find out the camera location.
        -- Sits behind the hero.
        -- Also apply the user controlled parameters azimoth and elevation.
        locStart =
            vec3 0 0 3.0

        locAz =
            Mat4.transform (Mat4.makeRotate azimoth (vec3 0 1 0)) locStart

        locElv =
            Mat4.transform
                (Mat4.makeRotate elevation
                    (Vec3.cross locAz (vec3 0 1 0))
                )
                locAz

        cameraTransformation =
            List.foldl
                Mat4.mul
                Mat4.identity
                [ Mat4.translate (vec3 0 hero.altitude 0) Mat4.identity
                , rotateAround
                , Mat4.translate earthLoc Mat4.identity
                ]

        cameraLocation =
            Mat4.transform cameraTransformation locElv

        -- And finally the up direction.
        up =
            Mat4.transform rotateAround Vec3.j
    in
    Mat4.makeLookAt cameraLocation
        targetLocation
        up


vertexShader : Shader Vertex Uniforms { vcolor : Vec3 }
vertexShader =
    [glsl|
     attribute vec3 position;
     attribute vec3 color;
     uniform mat4 perspective;
     uniform mat4 camera;
     uniform mat4 preScale;
     uniform mat4 preRotation;
     uniform mat4 preTranslation;
     uniform mat4 scale;
     uniform mat4 rotation;
     uniform mat4 translation;
     uniform mat4 postScale;
     uniform mat4 postRotation;
     uniform mat4 postTranslation;
     varying vec3 vcolor;
     void main () {
       gl_Position = (perspective * camera * 
                      postTranslation * postRotation * postScale * 
                      translation * rotation * scale *
                      preTranslation * preRotation * preScale * vec4(position, 1.0));
       vcolor = color;
     }
  |]


fragmentShader : Shader {} Uniforms { vcolor : Vec3 }
fragmentShader =
    [glsl|
    precision mediump float;
    uniform float shade;
    varying vec3 vcolor;
    void main () {
      gl_FragColor = shade * vec4(vcolor, 1.0);
    }
  |]


meshPositionMap : (Vec3 -> Vec3) -> MeshList -> MeshList
meshPositionMap fun mesh =
    case mesh of
        [] ->
            []

        ( v1, v2, v3 ) :: xs ->
            ( { v1 | position = fun v1.position }
            , { v2 | position = fun v2.position }
            , { v3 | position = fun v3.position }
            )
                :: meshPositionMap fun xs
