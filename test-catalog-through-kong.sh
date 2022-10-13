while true
do
curl -i -s  --location --request GET 'https://localhost:8443/catalog/items' \
--header 'apiKey: external-api-key'
sleep 0.2
echo ""
done
