using System.Text;
using System.Text.Json;

namespace CatalogAPIClient;

public class CatalogAPIClient
{
    private readonly HttpClient client;


    public CatalogAPIClient(HttpClient client)
    {
        this.client = client;
    }

    public void PostItem(string productId, string name, string description)
    {
        var json = JsonSerializer.Serialize(new { productId, name, description });
        var content = new StringContent(json, Encoding.UTF8, "application/json");

        client.PostAsync($"/catalog/items/", content)
             .Result
             .EnsureSuccessStatusCode();


    }

    public void PutItem(string productId, string name, string description)
    {
        var json = JsonSerializer.Serialize(new { name, description });
        var content = new StringContent(json, Encoding.UTF8, "application/json");

        client.PutAsync($"/catalog/items/{productId}", content)
            .Result
            .EnsureSuccessStatusCode();


    }

    public void UpdatePrice(string productId, double price)
    {
        var json = JsonSerializer.Serialize(new { Price = price });
        var content = new StringContent(json, Encoding.UTF8, "application/json");

        client.PutAsync($"/catalog/items/{productId}/price", content)
                .Result
                .EnsureSuccessStatusCode();


    }

}
