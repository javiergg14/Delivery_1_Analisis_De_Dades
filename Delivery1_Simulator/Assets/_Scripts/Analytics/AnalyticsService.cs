using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Envia al servidor los eventos del Simulator, de forma asincrona, y devuelve
/// al Simulator los ids que asigna la base de datos.
///
/// - Se crea SOLO al empezar la escena (no hay que anadirlo a ningun objeto).
/// - Desactiva en tiempo de ejecucion el AnalyticsManager original para que los
///   eventos no se envien dos veces. No se modifica ningun fichero entregado.
///
/// Colaboradores (SOLID):
///   IAnalyticsTransport : COMO se envia (HTTP por defecto)
///   AnalyticsForms      : QUE campos lleva cada evento
///   OfflineIdProvider   : ids locales si el servidor no responde
///   AnalyticsSettings   : configuracion
/// </summary>
public class AnalyticsService : MonoBehaviour
{
    private IAnalyticsTransport _transport;
    private readonly OfflineIdProvider _offlineIds = new OfflineIdProvider();

    // sessionId -> playerId, para avisar al Simulator al cerrar la sesion
    private readonly Dictionary<uint, uint> _sessionToPlayer = new Dictionary<uint, uint>();

    private int _failedRequests;

    /// <summary>Peticiones que han fallado definitivamente.</summary>
    public int FailedRequests => _failedRequests;

    /// <summary>Permite inyectar otro transporte (tests o canales alternativos).</summary>
    public void Initialize(IAnalyticsTransport transport) => _transport = transport;

    #region Arranque automatico
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    private static void AutoCreate()
    {
        if (FindAll<AnalyticsService>().Length > 0) return;

        var go = new GameObject("AnalyticsService");
        go.AddComponent<AnalyticsService>();
    }

    private static T[] FindAll<T>() where T : UnityEngine.Object
    {
#if UNITY_2023_1_OR_NEWER
        return FindObjectsByType<T>(FindObjectsSortMode.None);
#else
        return FindObjectsOfType<T>();
#endif
    }

    private void Awake()
    {
        if (_transport == null)
        {
            _transport = new HttpAnalyticsTransport(
                AnalyticsSettings.ServerUrl,
                AnalyticsSettings.TimeoutSeconds,
                AnalyticsSettings.MaxRetries,
                AnalyticsSettings.RetryDelaySeconds);
        }

        // Evita duplicados: el manager original queda desactivado (OnDisable lo desuscribe).
        foreach (AnalyticsManager legacy in FindAll<AnalyticsManager>())
        {
            legacy.enabled = false;
            Debug.Log("[Analytics] AnalyticsManager original desactivado; los eventos los envia AnalyticsService.");
        }
    }
    #endregion

    #region Suscripcion a eventos
    private void OnEnable()
    {
        Simulator.OnNewPlayer  += HandleNewPlayer;
        Simulator.OnNewSession += HandleNewSession;
        Simulator.OnBuyItem    += HandleBuyItem;
        Simulator.OnEndSession += HandleEndSession;
    }

    private void OnDisable()
    {
        Simulator.OnNewPlayer  -= HandleNewPlayer;
        Simulator.OnNewSession -= HandleNewSession;
        Simulator.OnBuyItem    -= HandleBuyItem;
        Simulator.OnEndSession -= HandleEndSession;
    }
    #endregion

    #region Manejadores (arrancan la corrutina y vuelven)
    private void HandleNewPlayer(string name, string country, int age, float gender, DateTime date)
        => StartCoroutine(SendNewPlayer(name, country, age, gender, date));

    private void HandleNewSession(DateTime date, uint playerId)
        => StartCoroutine(SendNewSession(date, playerId));

    private void HandleBuyItem(int itemId, DateTime date, uint sessionId)
        => StartCoroutine(SendPurchase(itemId, date, sessionId));

    private void HandleEndSession(DateTime date, uint sessionId)
    {
        if (_sessionToPlayer.TryGetValue(sessionId, out uint playerId))
            StartCoroutine(SendEndSession(date, sessionId, playerId));
    }
    #endregion

    #region Envio de cada evento
    private IEnumerator SendNewPlayer(string name, string country, int age, float gender, DateTime date)
    {
        AnalyticsResponse response = default;
        yield return _transport.Post(AnalyticsForms.Endpoint.AddPlayer,
            () => AnalyticsForms.NewPlayer(name, country, age, gender, date),
            r => response = r);

        uint playerId = ParseIdOrOffline(response, "player");
        CallbackEvents.OnAddPlayerCallback?.Invoke(playerId);
    }

    private IEnumerator SendNewSession(DateTime date, uint playerId)
    {
        uint sessionId;

        if (OfflineIdProvider.IsOffline(playerId))
        {
            // El jugador no existe en la BD: no se envia su sesion.
            sessionId = _offlineIds.Next();
        }
        else
        {
            AnalyticsResponse response = default;
            yield return _transport.Post(AnalyticsForms.Endpoint.AddSession,
                () => AnalyticsForms.NewSession(playerId, date),
                r => response = r);

            sessionId = ParseIdOrOffline(response, "session");
        }

        _sessionToPlayer[sessionId] = playerId;
        CallbackEvents.OnNewSessionCallback?.Invoke(sessionId);
    }

    private IEnumerator SendPurchase(int itemId, DateTime date, uint sessionId)
    {
        if (!OfflineIdProvider.IsOffline(sessionId))
        {
            AnalyticsResponse response = default;
            yield return _transport.Post(AnalyticsForms.Endpoint.AddPurchase,
                () => AnalyticsForms.Purchase(sessionId, itemId, date),
                r => response = r);

            if (!response.Success) RegisterFailure(response.Error);
        }

        CallbackEvents.OnItemBuyCallback?.Invoke(sessionId);
    }

    private IEnumerator SendEndSession(DateTime date, uint sessionId, uint playerId)
    {
        if (!OfflineIdProvider.IsOffline(sessionId))
        {
            AnalyticsResponse response = default;
            yield return _transport.Post(AnalyticsForms.Endpoint.EndSession,
                () => AnalyticsForms.EndSession(sessionId, date),
                r => response = r);

            if (!response.Success) RegisterFailure(response.Error);
        }

        _sessionToPlayer.Remove(sessionId);
        CallbackEvents.OnEndSessionCallback?.Invoke(playerId);
    }
    #endregion

    #region Utilidades
    /// <summary>El servidor devuelve el id como texto; si falla, se usa un id local reservado.</summary>
    private uint ParseIdOrOffline(AnalyticsResponse response, string what)
    {
        if (response.Success && uint.TryParse(response.Body, out uint id))
        {
            if (AnalyticsSettings.VerboseLogging) Debug.Log($"[Analytics] {what} id = {id}");
            return id;
        }

        RegisterFailure(response.Success ? $"invalid {what} id: '{response.Body}'" : response.Error);
        return _offlineIds.Next();
    }

    private void RegisterFailure(string error)
    {
        _failedRequests++;
        Debug.LogWarning($"[Analytics] request failed: {error}");
    }
    #endregion
}
