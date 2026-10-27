using System;
using System.Collections;
using UnityEngine;
using UnityEngine.Networking;

/// <summary>
/// Transporte HTTP no bloqueante basado en UnityWebRequest.
/// - Timeout corto para no dejar peticiones colgadas.
/// - Reintentos con espera exponencial SOLO ante fallos de red/servidor (5xx).
/// - Los errores 4xx (datos invalidos) no se reintentan: repetirlos no los arregla.
/// </summary>
public class HttpAnalyticsTransport : IAnalyticsTransport
{
    private readonly string _baseUrl;
    private readonly int _timeoutSeconds;
    private readonly int _maxRetries;
    private readonly float _retryDelaySeconds;

    public HttpAnalyticsTransport(string baseUrl, int timeoutSeconds = 10, int maxRetries = 2, float retryDelaySeconds = 1f)
    {
        _baseUrl = baseUrl.EndsWith("/") ? baseUrl : baseUrl + "/";
        _timeoutSeconds = timeoutSeconds;
        _maxRetries = Mathf.Max(0, maxRetries);
        _retryDelaySeconds = retryDelaySeconds;
    }

    public IEnumerator Post(string endpoint, Func<WWWForm> buildForm, Action<AnalyticsResponse> onDone)
    {
        string url = _baseUrl + endpoint;
        string lastError = "unknown error";

        for (int attempt = 0; attempt <= _maxRetries; attempt++)
        {
            bool retryable = true;

            using (UnityWebRequest www = UnityWebRequest.Post(url, buildForm()))
            {
                www.timeout = _timeoutSeconds;
                yield return www.SendWebRequest();

                if (www.result == UnityWebRequest.Result.Success)
                {
                    onDone?.Invoke(new AnalyticsResponse(true, www.downloadHandler.text.Trim(), null));
                    yield break;
                }

                lastError = www.error + " (" + endpoint + ")";
                if (www.result == UnityWebRequest.Result.ProtocolError &&
                    www.responseCode >= 400 && www.responseCode < 500)
                {
                    retryable = false;
                }
            }

            if (!retryable || attempt == _maxRetries)
                break;

            yield return new WaitForSeconds(_retryDelaySeconds * (1 << attempt));
        }

        onDone?.Invoke(new AnalyticsResponse(false, null, lastError));
    }
}
