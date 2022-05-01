module ObjLoader exposing (objMeshDecoder)

import Array

import Length exposing (Meters, inMeters)
import Quantity exposing (Unitless)
import Obj.Decode
import Obj.Decode exposing (ObjCoordinates)
import TriangularMesh exposing (TriangularMesh)
import Point3d exposing (Point3d, toRecord)
import Vector3d exposing (Vector3d)

import Math.Vector3 as Vec3 exposing (vec3, Vec3)

import WebGL exposing (Mesh)

import Common exposing (Vertex)


triangularMeshToMeshVertex :
  (TriangularMesh
    { position : Point3d Meters ObjCoordinates
    , normal : Vector3d Unitless ObjCoordinates
    }
  ) -> Mesh Vertex
triangularMeshToMeshVertex triangularMesh = 
  let vertices = TriangularMesh.faceVertices triangularMesh

      getColor loc = 
        let length = Vec3.length loc
            lowlimit = 1.00
            highlimit = 1.03
            factor = (length - lowlimit) / (highlimit - lowlimit)
        in
        if length <= lowlimit then (vec3 0 0 1)
        else (if length >= highlimit then (vec3 0.54 0.27 0.075)
              else (vec3 (factor*0.54 + (1-factor)*0.5) 
                         (factor*0.27 + (1-factor)*1.0) 
                         (factor*0.075 + (1-factor)*0.0)))

      posToVertex val = 
        let pos = Vec3.fromRecord (toRecord inMeters val.position)
        in
        { color = getColor pos
        , position = pos
        }

      convTriangle tri = case tri of (v1, v2, v3) -> ( posToVertex v1
                                                     , posToVertex v2
                                                     , posToVertex v3 )

      earthMesh = (List.map convTriangle vertices)
  in
    WebGL.triangles earthMesh


objMeshDecoder : Obj.Decode.Decoder (Mesh Vertex)
objMeshDecoder =
  Obj.Decode.map triangularMeshToMeshVertex Obj.Decode.faces
