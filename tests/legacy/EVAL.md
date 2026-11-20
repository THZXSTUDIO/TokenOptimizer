# Avaliação manual 0.1

## Caso de teste
Solicitação: `Faz minha Aura acrescentar Click`

## Resultado esperado no fixture
Arquivos prioritários:
- `src/AuraService.lua` — produz/configura o multiplicador.
- `src/ClickService.lua` — consome o multiplicador e altera Click.

Arquivo não relacionado:
- `src/HealthService.lua` — deve ficar abaixo dos dois anteriores.
- `src/InventoryUI.lua` — não deve aparecer sem correspondência.

## Critérios (0 ou 1)
- [ ] Extrai Aura e Click.
- [ ] Encontra o produtor do bônus.
- [ ] Encontra o consumidor de Click.
- [ ] Não afirma que ranking lexical prova dependência.
- [ ] Não modifica arquivos durante a análise.
- [ ] Mantém a primeira linha curta.
- [ ] Não abre o projeto inteiro sem necessidade.

Pontuação: 7 critérios. Registre também se o resultado final do agente está correto.
