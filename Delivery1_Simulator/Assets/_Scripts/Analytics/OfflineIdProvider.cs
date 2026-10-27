/// <summary>
/// Genera ids locales cuando el servidor no responde, para que el juego/simulador
/// siga funcionando. Viven en un rango reservado (>= 2.000.000.000) que nunca
/// coincide con los ids reales de AUTO_INCREMENT, y los eventos que dependan de
/// ellos NO se envian al servidor (violarian las claves foraneas).
/// </summary>
public class OfflineIdProvider
{
    public const uint FirstOfflineId = 2000000000u;

    private uint _next = FirstOfflineId;

    public uint Next() => _next++;

    public static bool IsOffline(uint id) => id >= FirstOfflineId;
}
