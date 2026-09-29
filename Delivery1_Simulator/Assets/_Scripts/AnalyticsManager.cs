using UnityEngine;
using UnityEngine.Networking;
using System;
using System.Collections;
using System.Collections.Generic;

public class AnalyticsManager : MonoBehaviour
{
    [SerializeField]
    private string serverUrl = "http://localhost/analytics/";

    private Dictionary<uint, uint> mapaSesionJugador = new Dictionary<uint, uint>();

    private uint idJugadorTemporal = 1;
    private uint idSesionTemporal = 100;

    private void OnEnable()
    {
        Simulator.OnNewPlayer += CapturarNuevoJugador;
        Simulator.OnNewSession += CapturarNuevaSesion;
        Simulator.OnBuyItem += CapturarCompra;
        Simulator.OnEndSession += CapturarFinSesion;
    }

    private void OnDisable()
    {
        Simulator.OnNewPlayer -= CapturarNuevoJugador;
        Simulator.OnNewSession -= CapturarNuevaSesion;
        Simulator.OnBuyItem -= CapturarCompra;
        Simulator.OnEndSession -= CapturarFinSesion;
    }

    private void CapturarNuevoJugador(string nombre, string pais, int edad, float genero, DateTime fecha)
    {
        StartCoroutine(EnviarNuevoJugador(nombre, pais, edad, genero, fecha));
    }

    private IEnumerator EnviarNuevoJugador(string nombre, string pais, int edad, float genero, DateTime fecha)
    {
        WWWForm form = new WWWForm();
        form.AddField("name", nombre);
        form.AddField("country", pais);
        form.AddField("age", edad);
        form.AddField("gender", genero.ToString(System.Globalization.CultureInfo.InvariantCulture));
        form.AddField("join_date", fecha.ToString("yyyy-MM-dd HH:mm:ss"));

        using (UnityWebRequest request = UnityWebRequest.Post(serverUrl + "add_player.php", form))
        {
            yield return request.SendWebRequest();

            uint newPlayerId = idJugadorTemporal;

            if (request.result == UnityWebRequest.Result.Success && uint.TryParse(request.downloadHandler.text, out uint serverId))
            {
                newPlayerId = serverId;
            }
            else
            {
                idJugadorTemporal++;
            }

            CallbackEvents.OnAddPlayerCallback?.Invoke(newPlayerId);
        }
    }

    private void CapturarNuevaSesion(DateTime fecha, uint idJugador)
    {
        StartCoroutine(EnviarNuevaSesion(fecha, idJugador));
    }

    private IEnumerator EnviarNuevaSesion(DateTime fecha, uint idJugador)
    {
        WWWForm form = new WWWForm();
        form.AddField("player_id", idJugador.ToString());
        form.AddField("start_date", fecha.ToString("yyyy-MM-dd HH:mm:ss"));

        using (UnityWebRequest request = UnityWebRequest.Post(serverUrl + "add_session.php", form))
        {
            yield return request.SendWebRequest();

            uint newSessionId = idSesionTemporal;

            if (request.result == UnityWebRequest.Result.Success && uint.TryParse(request.downloadHandler.text, out uint serverId))
            {
                newSessionId = serverId;
            }
            else
            {
                idSesionTemporal++;
            }

            mapaSesionJugador[newSessionId] = idJugador;
            CallbackEvents.OnNewSessionCallback?.Invoke(newSessionId);
        }
    }

    private void CapturarCompra(int idItem, DateTime fecha, uint idSesion)
    {
        StartCoroutine(EnviarCompra(idItem, fecha, idSesion));
    }

    private IEnumerator EnviarCompra(int idItem, DateTime fecha, uint idSesion)
    {
        WWWForm form = new WWWForm();
        form.AddField("session_id", idSesion.ToString());
        form.AddField("item_id", idItem.ToString());
        form.AddField("purchase_date", fecha.ToString("yyyy-MM-dd HH:mm:ss"));

        using (UnityWebRequest request = UnityWebRequest.Post(serverUrl + "add_purchase.php", form))
        {
            yield return request.SendWebRequest();
            CallbackEvents.OnItemBuyCallback?.Invoke(idSesion);
        }
    }

    private void CapturarFinSesion(DateTime fecha, uint idSesion)
    {
        if (mapaSesionJugador.TryGetValue(idSesion, out uint idJugador))
        {
            StartCoroutine(EnviarFinSesion(fecha, idSesion, idJugador));
        }
    }

    private IEnumerator EnviarFinSesion(DateTime fecha, uint idSesion, uint idJugador)
    {
        WWWForm form = new WWWForm();
        form.AddField("session_id", idSesion.ToString());
        form.AddField("end_date", fecha.ToString("yyyy-MM-dd HH:mm:ss"));

        using (UnityWebRequest request = UnityWebRequest.Post(serverUrl + "end_session.php", form))
        {
            yield return request.SendWebRequest();

            CallbackEvents.OnEndSessionCallback?.Invoke(idJugador);
            mapaSesionJugador.Remove(idSesion);
        }
    }
}