module Window.Onboarding.Address exposing
    ( Msg(..)
    , correctAddress
    , dropAppName
    , setError
    , update
    , view
    )

import Data.AddressConfig as AddressConfig exposing (AddressConfig)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Icons
import Locale exposing (Helpers)
import Ports
import String exposing (contains)
import Url
import Util.Keyboard as Keyboard
import Window.Onboarding.Context as Context exposing (Context)



-- UPDATE


type Msg
    = FillAddress String
    | RegisterRemote
    | RegistrationError String
    | CorrectAddress


setError : Context -> String -> ( Context, Cmd msg )
setError context message =
    ( Context.setAddressConfig context (AddressConfig.setError context.addressConfig message)
    , Ports.focus ".wizard__address"
    )


dropAppName : String -> String
dropAppName address =
    let
        ( instanceName, topDomain ) =
            case String.split "." address of
                [] ->
                    -- This can't happen because String.split always return a
                    -- list with at least one element but is required by Elm.
                    ( address, "mycozy.cloud" )

                [ instance ] ->
                    -- This should never happen as we already append
                    -- `.mycozy.cloud` to addresses without host
                    ( address, "mycozy.cloud" )

                instance :: rest ->
                    ( instance, String.join "." rest )
    in
    if String.isEmpty address then
        ""

    else if
        String.endsWith "mycozy.cloud" topDomain
            || String.endsWith "mytoutatice.cloud" topDomain
    then
        case String.split "-" instanceName of
            instance :: _ ->
                instance ++ "." ++ topDomain

            _ ->
                instanceName ++ "." ++ topDomain

    else
        -- We can't really tell at this point if the given URL points to a Cozy
        -- using nested domains or not so we can't really drop app names unless
        -- we make a hard list of them.
        instanceName ++ "." ++ topDomain


correctAddress : String -> String
correctAddress address =
    let
        { protocol, host, port_, path } =
            case Url.fromString address of
                Just url ->
                    url

                Nothing ->
                    Url.Url Url.Https address Nothing "" Nothing Nothing

        prependProtocol =
            if protocol == Url.Http || port_ == Just 80 then
                (++) "http://"

            else
                identity

        appendPort shortAddress =
            case ( protocol, port_ ) of
                ( Url.Http, Just 80 ) ->
                    shortAddress

                ( Url.Https, Just 443 ) ->
                    shortAddress

                ( _, Nothing ) ->
                    shortAddress

                ( _, Just p ) ->
                    shortAddress ++ ":" ++ String.fromInt p
    in
    host
        |> dropAppName
        |> prependProtocol
        |> appendPort


update : Msg -> Context -> ( Context, Cmd msg )
update msg context =
    case
        msg
    of
        FillAddress address ->
            ( Context.setAddressConfig context { address = address, error = "", busy = False }, Cmd.none )

        CorrectAddress ->
            let
                addressConfig =
                    context.addressConfig

                newAddressConfig =
                    { addressConfig
                        | address = correctAddress addressConfig.address
                    }
            in
            ( Context.setAddressConfig context newAddressConfig, Cmd.none )

        RegisterRemote ->
            let
                addressConfig =
                    context.addressConfig
            in
            if addressConfig.address == "" then
                setError context "Address You don't have filled the address!"

            else if contains "@" addressConfig.address then
                setError context "Address No email address"

            else if contains "mycosy.cloud" addressConfig.address then
                setError context "Address Cozy not cosy"

            else
                let
                    newAddressConfig =
                        { addressConfig | address = correctAddress addressConfig.address, busy = True }
                in
                ( Context.setAddressConfig context newAddressConfig
                , Ports.registerRemote (correctAddress newAddressConfig.address)
                )

        RegistrationError error ->
            setError context error



-- VIEW


view : Helpers -> Context -> Html Msg
view helpers context =
    div
        [ classList
            [ ( "step", True )
            , ( "step-address", True )
            , ( "step-error", context.addressConfig.error /= "" )
            ]
        ]
        [ div
            [ class "step-content" ]
            [ Icons.cozyBig
            , h1 [] [ text (helpers.t "Address Please introduce your cozy address") ]
            , if context.addressConfig.error == "" then
                p [ class "adress-helper" ]
                    [ text (helpers.t "Address This is the web address you use to sign in to your cozy.") ]

              else
                p [ class "error-message" ]
                    [ text (helpers.t context.addressConfig.error) ]
            , div [ class "coz-form-group" ]
                [ label [ class "coz-form-label" ]
                    [ text (helpers.t "Address Cozy address") ]
                , div [ class "https-input-wrapper" ]
                    [ span [ class "address_https" ]
                        [ text "https://" ]
                    , input
                        [ placeholder "cloudy.mycozy.cloud"
                        , classList
                            [ ( "wizard__address", True )
                            , ( "error", context.addressConfig.error /= "" )
                            ]
                        , type_ "text"
                        , value context.addressConfig.address
                        , disabled context.addressConfig.busy
                        , onInput FillAddress
                        , Keyboard.onEnter RegisterRemote
                        , onBlur CorrectAddress
                        ]
                        []
                    ]
                ]
            , div [ class "cozy-form-tip" ]
                [ text (helpers.t "Address Example Before")
                , strong [] [ text (helpers.t "Address Example Bold") ]
                , text (helpers.t "Address Example After")
                ]
            , a
                [ class "btn"
                , href "#"
                , if context.addressConfig.address == "" then
                    attribute "disabled" "true"

                  else if context.addressConfig.busy then
                    attribute "aria-busy" "true"

                  else
                    onClick RegisterRemote
                ]
                [ span [] [ text (helpers.t "Address Next") ] ]
            ]
        ]
