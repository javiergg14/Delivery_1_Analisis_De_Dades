using UnityEngine;
using UnityEngine.Networking;
using System;
using System.Collections;
using System.Collections.Generic;

public class AnalyticsManager : MonoBehaviour
{
    // Expone la URL en el editor de Unity. Cambia esto por la ruta de tu servidor de la UPC cuando la tengas.
    [SerializeField]
    private string serverUrl = "http://localhost/analytics/";

    // Variables para generar IDs temporales si el servidor falla, evitando que el juego se congele.
    private uint idJugadorTemporal = 1;
    private uint idSesionTemporal = 100;

    // Se ejecuta al activar el script. Nos suscribimos a los eventos del simulador original.
    private void OnEnable()
    {
        Simulator.OnNewPlayer += CapturarNuevoJugador;
        Simulator.OnNewSession += CapturarNuevaSesion;
        Simulator.OnBuyItem += CapturarCompra;
        Simulator.OnEndSession += CapturarFinSesion;
    }

    // Se ejecuta al desactivar el script. Limpiamos las suscripciones para evitar errores de memoria.
    private void OnDisable()
    {
        Simulator.OnNewPlayer -= CapturarNuevoJugador;
        Simulator.OnNewSession -= CapturarNuevaSesion;
        Simulator.OnBuyItem -= CapturarCompra;
        Simulator.OnEndSession -= CapturarFinSesion;
    }

    // Intercepta el evento de creación de jugador e inicia el envío asíncrono.
    private void CapturarNuevoJugador(string nombre, string pais, int edad, float genero, DateTime fecha)
    {
        StartCoroutine(EnviarNuevoJugador(nombre, pais, edad, genero, fecha));
    }

    // Corrutina para enviar los datos del jugador al servidor sin bloquear el juego.
    private IEnumerator EnviarNuevoJugador(string nombre, string pais, int edad, float genero, DateTime fecha)
    {
        // Empaqueta los datos en formato formulario para que PHP los lea en la variable $_POST.
        WWWForm form = new WWWForm();
        form.AddField("name", nombre);
        form.AddField("country", pais);
        form.AddField("age", edad);
        form.AddField("gender", genero.ToString());
        // Formatea la fecha al estándar ISO para asegurar compatibilidad con la base de datos MySQL.
        form.AddField("join_date", fecha.ToString("yyyy-MM-dd HH:mm:ss"));

        // Realiza la petición POST al archivo PHP correspondiente.
        using (UnityWebRequest request = UnityWebRequest.Post(serverUrl + "add_player.php", form))
        {
            // Pausa la ejecución de esta función hasta recibir respuesta. El juego principal sigue corriendo.
            yield return request.SendWebRequest();

            uint newPlayerId = idJugadorTemporal;

            // Si la conexión es exitosa y el servidor devuelve un ID válido, lo asignamos.
            if (request.result == UnityWebRequest.Result.Success && uint.TryParse(request.downloadHandler.text, out uint serverId))
            {
                newPlayerId = serverId;
            }
            else
            {
                // Si la conexión falla, incrementamos el ID temporal local.
                idJugadorTemporal++;
            }

            // Avisamos al simulador de que hemos terminado y le pasamos el ID para que continúe su ciclo.
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

            // Guardamos la relación entre la nueva sesión y el jugador que la inició.
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

            // La compra no requiere devolver IDs nuevos al simulador, solo avisar de que el proceso terminó.
            CallbackEvents.OnItemBuyCallback?.Invoke(idSesion);
        }
    }

    private void CapturarFinSesion(DateTime fecha, uint idSesion)
    {
        // Buscamos el ID del jugador asociado a esta sesión usando el diccionario en memoria.
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

            // Devolvemos el ID del jugador original al simulador, tal como lo exige su arquitectura.
            CallbackEvents.OnEndSessionCallback?.Invoke(idJugador);
            // Eliminamos el registro del diccionario para liberar la memoria RAM.
            mapaSesionJugador.Remove(idSesion);
        }
    }
}