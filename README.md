# ForeverGroups

Localizador de grupos para o WoW Forever, feito do zero para substituir o LFG Forever. Usa o localizador da própria Blizzard (`C_LFGList`) por baixo, com uma janela mais completa por cima.

## Como usar

- `/fg` abre e fecha a janela. Também abre pelo botão do minimapa, pelo menu de addons, por uma tecla de atalho (Opções > Teclas de atalho > ForeverGroups) e por uma aba na janela do Localizador de Grupos da Blizzard.
- `/fg config` abre as opções; `/fg reset` restaura posição e tamanho da janela.

## Recursos

- **Busca** por categoria e atividades. Sem atividade marcada, busca todas. Por padrão, só aparecem atividades do seu nível; isso pode ser mudado nas opções.
- **Filtros de grupos**: falta tanque, cura ou dano; já tem tanque ou cura; esconder grupos que tenham certas classes.
- **Filtros de jogadores**: função, classe e faixa de nível.
- **Mais filtros**: estilo de jogo e idiomas.
- **Filtrar resultados** por texto (líder, comentário, atividade, zona), sem precisar buscar de novo.
- **Meus filtros**: salvar até 10 combinações com nome. Os filtros da última busca voltam na próxima sessão.
- **Listas** de grupos e jogadores com os mesmos ícones da Blizzard. Seu anúncio vem primeiro, depois guilda e amigos. Jogadores podem ser ordenados por recentes, antigos, nível ou classe.
- **Ações por linha**: convidar e pedir para entrar, com mensagens prontas. Clique direito abre o menu da Blizzard (sussurrar, denunciar...), e Shift+clique abre um sussurro.
- **Mensagens com marcadores**: `%class%`, `%level%`, `%talents%`, `%points%`, `%role%`, `%name%` e `%dungeon%`. São salvas por personagem.
- **Registro de sussurros** desde o login, com contador de não lidos na aba e no minimapa e ações Responder, Onde está, Convidar e Remover.
- **Verificar funções** do grupo, para líder ou assistente.
- Abas laterais para criar anúncio, procurar grupos e a Lista de Quem da Blizzard.

## Notas técnicas

- Em masmorras e raides, vários dados da busca e do chat chegam "secretos". Eles só são exibidos, nunca comparados. Por isso, os filtros deixam passar o que não conseguem ler, em vez de esconder.
- A lista só é montada com a janela aberta. Resultados que chegam com a janela fechada só marcam a lista como desatualizada.
- Cada resultado é lido uma vez por montagem. Os membros de um grupo só são lidos se o filtro de classes estiver ligado.
