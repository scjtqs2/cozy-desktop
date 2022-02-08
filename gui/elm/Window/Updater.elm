module Window.Updater exposing
    ( Model
    , Msg(..)
    , humanReadableDiskValue
    , init
    , subscriptions
    , update
    , view
    )

import Data.Progress exposing (Progress)
import Html exposing (..)
import Html.Attributes exposing (..)
import I18n exposing (Helpers)
import Icons
import Ports
import View.ProgressBar as ProgressBar



-- MODEL


type alias Model =
    { version : String
    , progress : Maybe Progress
    , error : Maybe String
    }


init : String -> Model
init version =
    { version = version
    , progress = Nothing
    , error = Nothing
    }



-- UPDATE


type Msg
    = UpdateDownloading (Maybe Progress)
    | UpdateError String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateDownloading progress ->
            ( { model | progress = progress }, Cmd.none )

        UpdateError subMsg ->
            ( { model | error = Just subMsg }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.updateDownloading UpdateDownloading
        , Ports.updateError UpdateError
        ]



-- VIEW


humanReadableDiskValue : Helpers -> Float -> String
humanReadableDiskValue helpers v =
    String.fromInt (round (v / 1000000)) ++ " M" ++ helpers.t "Account b"


view : Helpers -> Model -> Html Msg
view helpers model =
    section [ class "updater" ]
        (case ( model.error, model.progress ) of
            ( Just msg, _ ) ->
                [ h1 [] [ text (helpers.t "Updater Error") ]
                , p [] [ text msg ]
                ]

            ( Nothing, Just progress ) ->
                progressView helpers
                    [ ProgressBar.view (progress.transferred / progress.total)
                    , div [ class "progress-indicator" ]
                        [ text
                            (humanReadableDiskValue helpers progress.transferred
                                ++ " / "
                                ++ humanReadableDiskValue helpers progress.total
                            )
                        ]
                    ]

            ( Nothing, Nothing ) ->
                progressView helpers
                    [ span [ class "progress-spinner" ] [] ]
        )


progressView : Helpers -> List (Html Msg) -> List (Html Msg)
progressView helpers localProgressBar =
    [ h1 []
        [ figure [ class "logo" ] [ Icons.logo ]
        , text (helpers.t "Updater Downloading")
        ]
    , div [ class "spacer" ]
        localProgressBar
    , p []
        [ strong [] [ text (helpers.t "Updater Please wait") ]
        , br [] []
        , text (helpers.t "Updater It may take a while")
        ]
    ]
