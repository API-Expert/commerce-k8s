using System;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CatalogAPIClient
{
    public static class Extensions
    {
        public static IServiceCollection AddCatalogAPIClient(this IServiceCollection services)
        {

            services.AddSingleton<CatalogAPIClient>();
            services.AddHttpClient<CatalogAPIClient>("catalogapi", (services, client) =>
            {
                var baseUrl = services.GetRequiredService<IConfiguration>().GetSection("CatalogAPI").GetValue<string>("baseurl");
                client.BaseAddress = new Uri(baseUrl);
            });

            return services;
        }
    }
}

