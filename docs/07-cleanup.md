# 7. Cleanup

APIM Developer custa ~US$50/mês mesmo parado. Quando terminar o tutorial, **destrua o ambiente**.

## 7.1 Via Terraform (recomendado)

```bash
cd terraform
terraform destroy
```

Confirme com `yes`. A destruição completa leva ~15-20 minutos (a maior parte é o APIM sendo desprovisionado).

> 💡 Use `terraform destroy -auto-approve` se for um ambiente claramente de tutorial sem risco de perda de dados.

## 7.2 Via Azure CLI

Se você criou via portal, basta deletar o Resource Group:

```bash
RG=rg-internalapim-dev-brs

# Confirme antes
az resource list -g $RG -o table

# Delete o RG inteiro (assíncrono)
az group delete -n $RG --yes --no-wait
```

## 7.3 Soft-delete do APIM

O Azure mantém o nome do APIM **reservado por 48h** após a deleção (soft-delete). Se você precisa recriar com o mesmo nome imediatamente:

```bash
# Listar APIMs em soft-delete
az apim deletedservice list -o table

# Purgar permanentemente
az apim deletedservice purge --location brazilsouth --service-name apim-internalapim-owner-dev
```

> ⚠️ Soft-delete não gera custo. Mas se você quer recriar **na hora**, é preciso purgar.

## 7.4 Limpeza local

```bash
cd terraform
rm -f terraform.tfstate terraform.tfstate.backup tfplan
rm -rf .terraform/
```

## 7.5 Verificação final

```bash
az group exists -n rg-internalapim-dev-brs
# false → cleanup OK
```

---

⬅️ Anterior: [Validação](06-validacao.md) | ➡️ Próximo: [Cleanup](07-cleanup.md)
