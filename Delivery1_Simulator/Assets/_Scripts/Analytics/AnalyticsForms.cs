using System;
using System.Globalization;
using UnityEngine;

/// <summary>
/// Serializa cada evento al formulario que esperan los PHP del servidor.
/// Un unico sitio que conoce los nombres de los campos: si cambia el contrato
/// con el servidor, solo se toca este fichero.
/// </summary>
public static class AnalyticsForms
{
    private const string DateFormat = "yyyy-MM-dd HH:mm:ss";

    // Nombres de los endpoints (ficheros PHP)
    public static class Endpoint
    {
        public const string AddPlayer   = "add_player.php";
        public const string AddSession  = "add_session.php";
        public const string AddPurchase = "add_purchase.php";
        public const string EndSession  = "end_session.php";
    }

    private static string D(DateTime date) => date.ToString(DateFormat, CultureInfo.InvariantCulture);

    public static WWWForm NewPlayer(string name, string country, int age, float gender, DateTime joinDate)
    {
        var f = new WWWForm();
        f.AddField("name", name);
        f.AddField("country", country);
        f.AddField("age", age);
        f.AddField("gender", gender.ToString(CultureInfo.InvariantCulture)); // punto decimal siempre
        f.AddField("join_date", D(joinDate));
        return f;
    }

    public static WWWForm NewSession(uint playerId, DateTime startDate)
    {
        var f = new WWWForm();
        f.AddField("player_id", playerId.ToString());
        f.AddField("start_date", D(startDate));
        return f;
    }

    public static WWWForm Purchase(uint sessionId, int itemId, DateTime purchaseDate)
    {
        var f = new WWWForm();
        f.AddField("session_id", sessionId.ToString());
        f.AddField("item_id", itemId);
        f.AddField("purchase_date", D(purchaseDate));
        return f;
    }

    public static WWWForm EndSession(uint sessionId, DateTime endDate)
    {
        var f = new WWWForm();
        f.AddField("session_id", sessionId.ToString());
        f.AddField("end_date", D(endDate));
        return f;
    }
}
