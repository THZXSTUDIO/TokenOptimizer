# Avaliação manual 0.3

## Caso
Solicitação: AURA -> CLICK MULTIPLIER | ROBLOX

## Comportamento esperado
- [ ] Identifica Aura e Click como sementes.
- [ ] Descobre arquivos relacionados por uma aresta Graphify mesmo sem palavra-chave no nome.
- [ ] Complementa nós Graphify ausentes com busca apenas por nomes de arquivos em src.
- [ ] Exclui .bak, .before-*, backups, _Legado, desativados e gerados.
- [ ] Agrupa arquivos por domínio.
- [ ] Produz AgentPlan Markdown e Canvas Manager -> Domain -> Files.
- [ ] Não lê conteúdo-fonte nem modifica código do jogo durante o roteamento.
- [ ] Distingue subagentes reais de passagens sequenciais por domínio.
- [ ] Cada domínio recebe missão limitada e formato de evidência.
- [ ] O gerente reúne resultados e remove duplicações.

## Limites
- Expansão Graphify de um salto por padrão.
- Até 12 arquivos-semente e 8 vizinhos adicionais por padrão.
- Relações e scores são pistas, não prova.
- Tokens reais só são relatados se a interface/runtime os expuser.
