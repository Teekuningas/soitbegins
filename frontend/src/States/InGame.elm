module States.InGame exposing (Msg, subscriptions, update, view)

import Browser.Dom exposing (getViewportOf)
import Browser.Events exposing (onAnimationFrame, onResize)
import Communication.Flags
import Communication.Receiver as Receiver
import HUD.Controller as Controller
    exposing
        ( controllerMeshDown
        , controllerMeshUp
        , controllerUnif
        , handleDown
        , handleMove
        , handleUp
        )
import HUD.Page exposing (embedInCanvas)
import HUD.Widgets
    exposing
        ( Msg(..)
        , debugOverlay
        , fpsOverlay
        , overviewToggleOverlay
        )
import Html exposing (Html)
import Html.Attributes exposing (class)
import Html.Events.Extra.Mouse as Mouse
import Html.Events.Extra.Touch as Touch
import List
import Model.Model
    exposing
        ( DragState(..)
        , GameData
        , Model(..)
        )
import Platform.Cmd
import Platform.Sub
import Task
import Time
import WebGL
import World.Update exposing (updateGameData)
import World.World as World
    exposing
        ( axisMesh
        , axisUnif
        , earthUnif
        , fireMesh
        , fireUnif
        , heroMesh
        , heroUnif
        , sunMesh
        , sunUnif
        )


type Msg
    = TimeElapsed Time.Posix
    | ResizeMsg
    | PointerEventMsg PointerEvent
    | ViewportMsg (Result Browser.Dom.Error Browser.Dom.Viewport)
    | RecvServerMsg Receiver.RecvServerValue
    | RecvServerMsgError String
    | UpdateTimeMsg Time.Posix
    | WidgetsMsg HUD.Widgets.Msg


type PointerEvent
    = MouseUp Mouse.Event
    | MouseDown Mouse.Event
    | MouseMove Mouse.Event
    | TouchMove Touch.Event
    | TouchDown Touch.Event
    | TouchUp Touch.Event


subscriptions : GameData -> Sub Msg
subscriptions gameData =
    Platform.Sub.batch
        [ onAnimationFrame (\x -> TimeElapsed x)
        , onResize (\width height -> ResizeMsg)
        , Receiver.messageReceiver recvServerJson
        ]


view : GameData -> Html Msg
view gameData =
    let
        earth =
            gameData.earth

        renderData =
            gameData.renderData

        canvasDimensions =
            gameData.canvasDimensions

        camera =
            gameData.camera

        hero =
            gameData.hero

        earthMesh =
            gameData.earthMesh

        overviewToggle =
            gameData.overviewToggle

        containerAttrs =
            if overviewToggle then
                [ class "background-black" ]

            else
                []
    in
    embedInCanvas
        containerAttrs
        [ Html.map WidgetsMsg (fpsOverlay renderData)
        , Html.map WidgetsMsg (overviewToggleOverlay gameData.overviewToggle)
        , Html.map WidgetsMsg (debugOverlay gameData)
        ]
        [ Touch.onEnd (PointerEventMsg << TouchUp)
        , Touch.onStart (PointerEventMsg << TouchDown)
        , Touch.onMove (PointerEventMsg << TouchMove)
        , Mouse.onUp (PointerEventMsg << MouseUp)
        , Mouse.onDown (PointerEventMsg << MouseDown)
        , Mouse.onMove (PointerEventMsg << MouseMove)
        ]
        [ WebGL.entity
            World.vertexShader
            World.fragmentShader
            heroMesh
            (heroUnif overviewToggle canvasDimensions earth hero camera)
        , WebGL.entity
            World.vertexShader
            World.fragmentShader
            fireMesh
            (fireUnif overviewToggle canvasDimensions earth hero camera)
        , WebGL.entity
            World.vertexShader
            World.fragmentShader
            earthMesh
            (earthUnif overviewToggle canvasDimensions earth hero camera)
        , WebGL.entity
            World.vertexShader
            World.fragmentShader
            axisMesh
            (axisUnif overviewToggle canvasDimensions earth hero camera)
        , WebGL.entity
            World.vertexShader
            World.fragmentShader
            sunMesh
            (sunUnif overviewToggle canvasDimensions earth hero camera)
        , WebGL.entity
            Controller.vertexShader
            Controller.fragmentShader
            controllerMeshUp
            (controllerUnif canvasDimensions
                (if gameData.controller.upButtonDown then
                    1.0

                 else
                    0.5
                )
            )
        , WebGL.entity
            Controller.vertexShader
            Controller.fragmentShader
            controllerMeshDown
            (controllerUnif canvasDimensions
                (if gameData.controller.downButtonDown then
                    1.0

                 else
                    0.5
                )
            )
        ]


update : Msg -> GameData -> ( Model, Cmd Msg )
update msg gameData =
    case msg of
        RecvServerMsgError message ->
            let
                newGameLoaderData =
                    { earth = Nothing
                    , renderData = Nothing
                    , connectionData = Nothing
                    , earthMesh = gameData.earthMesh
                    , canvasDimensions = gameData.canvasDimensions
                    }
            in
            ( InGameLoader newGameLoaderData, Cmd.none )

        RecvServerMsg message ->
            let
                msgEarth =
                    { rotationAroundSun = message.earth.rotationAroundSun
                    , rotationAroundAxis = message.earth.rotationAroundAxis
                    }

                newEarth =
                    { msgEarth = msgEarth
                    , previousMsgEarth =
                        gameData.connectionData.earth.msgEarth
                    }

                connectionData =
                    gameData.connectionData

                newConnectionData =
                    { connectionData | earth = newEarth }

                newGameData =
                    { gameData | connectionData = newConnectionData }
            in
            ( InGame newGameData
            , Task.perform UpdateTimeMsg Time.now
            )

        UpdateTimeMsg dt ->
            let
                msgElapsed =
                    toFloat (Time.posixToMillis dt)

                newElapsedData =
                    { msgElapsed = msgElapsed
                    , previousMsgElapsed =
                        gameData.connectionData.elapsed.msgElapsed
                    }

                connectionData =
                    gameData.connectionData

                newConnectionData =
                    { connectionData | elapsed = newElapsedData }

                newGameData =
                    { gameData | connectionData = newConnectionData }
            in
            ( InGame newGameData
            , Cmd.none
            )

        TimeElapsed dt ->
            let
                elapsed =
                    toFloat (Time.posixToMillis dt)

                previousElapsed =
                    gameData.renderData.elapsed

                newRenderData =
                    { elapsed = elapsed
                    , previousElapsed = previousElapsed
                    }

                connectionData =
                    gameData.connectionData

                earthData =
                    connectionData.earth

                elapsedData =
                    connectionData.elapsed

                updatedGameData =
                    updateGameData
                        elapsed
                        previousElapsed
                        elapsedData.msgElapsed
                        elapsedData.previousMsgElapsed
                        earthData.msgEarth
                        earthData.previousMsgEarth
                        gameData

                cmd =
                    if updatedGameData.refreshed == False then
                        Task.attempt ViewportMsg (getViewportOf "webgl-canvas")

                    else
                        Cmd.none

                newGameData =
                    { updatedGameData
                        | renderData = newRenderData
                        , refreshed = True
                    }
            in
            ( InGame newGameData
            , cmd
            )

        PointerEventMsg event ->
            case event of
                MouseUp struct ->
                    let
                        newController =
                            handleUp gameData.controller

                        newGameData =
                            { gameData | controller = newController }
                    in
                    ( InGame newGameData, Cmd.none )

                MouseDown struct ->
                    let
                        newController =
                            handleDown
                                gameData.controller
                                struct.offsetPos
                                gameData.canvasDimensions

                        newGameData =
                            { gameData | controller = newController }
                    in
                    ( InGame newGameData, Cmd.none )

                MouseMove struct ->
                    let
                        ( newController, newCamera ) =
                            handleMove
                                gameData.controller
                                gameData.camera
                                struct.offsetPos

                        newGameData =
                            { gameData
                                | controller = newController
                                , camera = newCamera
                            }
                    in
                    ( InGame newGameData
                    , Cmd.none
                    )

                TouchUp struct ->
                    let
                        controller =
                            gameData.controller

                        newController =
                            { controller
                                | upButtonDown = False
                                , downButtonDown = False
                                , dragState = NoDrag
                            }

                        newGameData =
                            { gameData | controller = newController }
                    in
                    ( InGame newGameData
                    , Cmd.none
                    )

                TouchDown struct ->
                    case List.head struct.touches of
                        Nothing ->
                            ( InGame gameData, Cmd.none )

                        Just x ->
                            let
                                newController =
                                    handleDown
                                        gameData.controller
                                        x.clientPos
                                        gameData.canvasDimensions

                                newGameData =
                                    { gameData | controller = newController }
                            in
                            ( InGame newGameData
                            , Cmd.none
                            )

                TouchMove struct ->
                    case List.head struct.touches of
                        Nothing ->
                            ( InGame gameData, Cmd.none )

                        Just x ->
                            let
                                ( newController, newCamera ) =
                                    handleMove
                                        gameData.controller
                                        gameData.camera
                                        x.clientPos

                                newGameData =
                                    { gameData
                                        | controller = newController
                                        , camera = newCamera
                                    }
                            in
                            ( InGame newGameData
                            , Cmd.none
                            )

        ResizeMsg ->
            ( InGame gameData, Task.attempt ViewportMsg (getViewportOf "webgl-canvas") )

        ViewportMsg returnValue ->
            let
                newCanvasDimensions =
                    returnValue
                        |> Result.map .viewport
                        |> Result.map
                            (\v ->
                                { width = round v.width
                                , height = round v.height
                                }
                            )
                        |> Result.withDefault gameData.canvasDimensions

                newGameData =
                    { gameData | canvasDimensions = newCanvasDimensions }
            in
            ( InGame newGameData
            , Cmd.none
            )

        WidgetsMsg widgetsMsg ->
            case widgetsMsg of
                OverviewToggleMsg ->
                    let
                        newGameData =
                            { gameData | overviewToggle = not gameData.overviewToggle }
                    in
                    ( InGame newGameData
                    , Cmd.none
                    )



-- Some helpers.


recvServerJson : String -> Msg
recvServerJson value =
    case Receiver.decodeJson value of
        Ok result ->
            RecvServerMsg result

        Err errorMessage ->
            RecvServerMsgError "Error while communicating with the server"
