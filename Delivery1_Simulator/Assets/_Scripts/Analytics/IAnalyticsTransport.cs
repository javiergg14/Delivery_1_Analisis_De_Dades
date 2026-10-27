using System;
using System.Collections;
using UnityEngine;

/// <summary>Resultado de una peticion al servidor de analytics.</summary>
public readonly struct AnalyticsResponse
{
    public readonly bool Success;
    public readonly string Body;   // cuerpo de la respuesta (p. ej. el id insertado)
    public readonly string Error;  // mensaje de error si Success == false

    public AnalyticsResponse(bool success, string body, string error)
    {
        Success = success;
        Body = body;
        Error = error;
    }
}

/// <summary>
/// Abstrae COMO se envian los datos. AnalyticsManager solo conoce esta interfaz,
/// asi se puede cambiar HTTP por otro canal (o por un mock en tests) sin tocarlo.
/// </summary>
public interface IAnalyticsTransport
{
    /// <summary>
    /// Envia un POST a <paramref name="endpoint"/> y llama a <paramref name="onDone"/> al terminar.
    /// El formulario se construye con una factoria porque un WWWForm no se puede reutilizar entre reintentos.
    /// </summary>
    IEnumerator Post(string endpoint, Func<WWWForm> buildForm, Action<AnalyticsResponse> onDone);
}
