# DreeZy Hub - Universal Script

> [!NOTE]
> **Versão Atual: V1.0.9 (Refactor Update)**
> Agora o projeto está modularizado para facilitar atualizações e manutenção.

## Como Usar
Execute o arquivo `DreeZyHub_Loader.lua`. Ele carregará automaticamente os módulos necessários da pasta `Modules/`.
Certifique-se de que a pasta `Modules` está na mesma pasta que o script (workspace).

## Funcionalidades
### ⚔️ Combate
- **Aimbot**: Focado na cabeça/corpo com suavização e FOV configurável.
- **Modo Legit**: Aleatoriza a parte do corpo (Cabeça 40%, Outros 60%).
- **Kill Aura**: Teleporta para as costas do inimigo mais próximo e trava nele (NOVO).
- **Team Check**: Ignora aliados.

### 👁️ Visual (ESP)
- **Boxes**: Caixas 2D ao redor dos jogadores.
- **Nomes**: Mostra nomes dos jogadores.
- **LifeBar**: Barra de vida dinâmica.
- **Tracers**: Linhas da base da tela até o jogador (NOVO).
- **Head Expander**: Aumenta o tamanho da cabeça dos inimigos ("Cabeças de Cearense").

### 👤 Local & Utilidades
- **Respawn Onde Morreu**: Retorna a posição da morte após renascer.
- **Mouse Unlocker**: Trava/Destrava o cursor com tecla configurável (padrão: P).
- **Interface**: Voidware UI (Roxo/Dark) com animações e efeitos de neve.
- **Save/Load**: Salva todas as suas configurações em JSON.

## Estrutura de Arquivos (V1.0.9)
- `DreeZyHub_Loader.lua`: Script Principal (Execute este).
- `Modules/`: Pasta com os códigos divididos.
  - `UI.lua`: Biblioteca Visual.
  - `Combat.lua`: Aimbot e Kill Aura.
  - `Visuals.lua`: ESP e Head Expand.
  - `Utility.lua`: Respawn e Mouse Fix.

---
Criado por **DreeZy**
