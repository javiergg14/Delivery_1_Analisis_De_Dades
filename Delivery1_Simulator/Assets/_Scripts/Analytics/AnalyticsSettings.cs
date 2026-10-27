/// <summary>
/// Unico sitio con la configuracion del envio de analytics.
/// Es un script propio (no se toca ningun script ni escena entregados).
/// </summary>
public static class AnalyticsSettings
{
    /// <summary>URL base donde estan los PHP (con o sin / final).</summary>
    public const string ServerUrl = "https://citmalumnes.upc.es/~javiergg16/";

    /// <summary>Segundos maximos de espera por peticion.</summary>
    public const int TimeoutSeconds = 10;

    /// <summary>Reintentos ante fallo de red / error 5xx (0 = sin reintentos).</summary>
    public const int MaxRetries = 2;

    public const float RetryDelaySeconds = 1f;

    /// <summary>Muestra en consola cada id recibido del servidor.</summary>
    public static readonly bool VerboseLogging = false;
}
