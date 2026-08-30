-- Complétion : popup automatique pendant la frappe (défaut blink), sans
-- l'aperçu inline gris. <C-Space> ouvre/ferme le menu manuellement.

-- ── Qualité de correspondance, façon VSCode ────────────────────────────────
-- VSCode ne filtre PAS sur le préfixe : son scorer (fuzzyScore) accepte
-- n'importe quelle sous-séquence, donc `my` y propose aussi `moveBy`. Ce qui
-- change, c'est le barème : un caractère qui tombe en début de mot ou sur une
-- frontière camelCase vaut 7 points, ailleurs il en vaut 1. L'écart est tel
-- que le bruit part tout en bas.
-- frizbee (le matcher Rust de blink) donne 16 points à TOUT caractère apparié,
-- avec des bonus marginaux : sur `my`, `moveBy` marque 36 contre 48 pour
-- `myArrayTest` — assez pour squatter les 8 lignes du menu aux côtés de
-- `MediaKeys`, `MimeTypeArray` & co (les globales du DOM que renvoie vtsls).
-- On rétablit la hiérarchie en classant d'abord par qualité :
--   0  préfixe exact, casse comprise   my  -> myArrayTest
--   1  préfixe, casse ignorée          my  -> MyThing
--   2  initiales de mots               mkm -> MediaKeyMessageEvent
--   3  le reste, sous-séquence lâche   my  -> moveBy
-- ...puis on coupe tout ce qui dépasse le rang 2. C'est plus strict que
-- VSCode, c'est voulu. Filet de sécurité : si RIEN n'atteint le rang 2, on ne
-- coupe rien — taper `arr` continue donc de proposer `myArrayTest`.
local MAX_RANK = 2

-- Cache des rangs, remis à zéro dès que le mot tapé change. Table à clés
-- faibles : on n'empêche pas les items d'être ramassés par le GC, et surtout
-- on n'écrit pas de champs parasites dans les items (blink les recopie tels
-- quels vers `completionItem/resolve`).
local cache = { keyword = nil, ranks = setmetatable({}, { __mode = "k" }) }

-- Le mot en cours de frappe, tel que blink le découpe lui-même.
local function current_keyword()
  local ok, fuzzy = pcall(require, "blink.cmp.fuzzy")
  if not ok then return "" end
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local range = require("blink.cmp.config").completion.keyword.range
  local start_col, end_col = fuzzy.get_keyword_range(line, col, range)
  return line:sub(start_col + 1, end_col)
end

-- "MediaKeyMessageEvent" -> "mkme" ; "min_keyword_length" -> "mkl"
local function initials(text)
  local out, prev = {}, ""
  for i = 1, #text do
    local c = text:sub(i, i)
    local boundary = i == 1
      or prev:match("[%s_%-%.]") ~= nil
      or (c:match("%u") ~= nil and prev:match("%u") == nil)
    if boundary then out[#out + 1] = c:lower() end
    prev = c
  end
  return table.concat(out)
end

local function match_rank(item, keyword)
  if cache.keyword ~= keyword then
    cache.keyword = keyword
    cache.ranks = setmetatable({}, { __mode = "k" })
  end
  local rank = cache.ranks[item]
  if rank == nil then
    local text = item.filterText or item.label or ""
    if text:sub(1, #keyword) == keyword then
      rank = 0
    elseif text:lower():sub(1, #keyword) == keyword:lower() then
      rank = 1
    elseif initials(text):find(keyword:lower(), 1, true) == 1 then
      rank = 2
    else
      rank = 3
    end
    cache.ranks[item] = rank
  end
  return rank
end

-- `max_items` est rappelé à chaque frappe avec la liste complète, déjà filtrée
-- et triée : c'est le seul point d'accroche de blink qui permette de couper en
-- direct. On renvoie le nombre d'items de cette source à conserver — comme le
-- tri ci-dessous a mis les meilleurs rangs devant, couper au compte revient à
-- ne garder qu'eux. `nil` = pas de coupe.
-- Le filet de sécurité se juge sur TOUTES les sources, pas source par source :
-- sinon une source dépourvue de bonne correspondance se croirait dispensée de
-- coupe et viendrait remplir le menu — les snippets `dateDMY`/`dateMDY` sur
-- `my`, par exemple — pendant que le LSP, lui, a bien été réduit à ses deux
-- vrais résultats.
local function keep_best(source_id)
  return function(_, items)
    local keyword = current_keyword()
    if #keyword == 0 then return nil end
    local good_anywhere, good_here = 0, 0
    for _, item in ipairs(items) do
      if match_rank(item, keyword) <= MAX_RANK then
        good_anywhere = good_anywhere + 1
        if item.source_id == source_id then good_here = good_here + 1 end
      end
    end
    -- Rien de correct nulle part (`arr` -> `myArrayTest`) : on laisse tout
    -- passer, le classement flou reprend la main.
    if good_anywhere == 0 then return nil end
    return good_here
  end
end

return {
  {
    "saghen/blink.cmp",
    opts = {
      fuzzy = {
        -- `sorts` peut être une fonction : blink l'appelle une fois par frappe
        -- pour obtenir la liste des comparateurs. On en profite pour calculer
        -- le mot tapé une seule fois et le capturer dans la fermeture.
        -- NB : glisser un comparateur Lua ici fait basculer le tri du Rust
        -- vers Lua. Le cache de rangs garde ça à quelques dixièmes de ms.
        sorts = function()
          local keyword = current_keyword()
          return {
            function(a, b)
              if #keyword == 0 then return nil end
              local ra, rb = match_rank(a, keyword), match_rank(b, keyword)
              if ra ~= rb then return ra < rb end
            end,
            "score",
            "sort_text",
          }
        end,
      },
      completion = {
        -- Pas d'aperçu inline gris de la sélection en cours.
        ghost_text = { enabled = false },
        list = {
          -- Menu court : 8 candidats au maximum, pas de scroll.
          max_items = 8,
          -- Comme dans VSCode : naviguer dans le menu ne fait que surligner,
          -- rien n'est écrit dans le buffer avant <Tab> / <CR>.
          selection = { auto_insert = false },
        },
        -- 8 lignes visibles, aligné sur max_items.
        menu = { max_height = 8 },
      },
      sources = {
        -- Sur UNE lettre il n'y a rien à discriminer : tout ce qui commence
        -- par `m` commence vraiment par `m`, et le menu se remplit de
        -- `moveTo`/`menubar`/`matchMedia`. On n'ouvre donc qu'à partir de 2
        -- caractères. Ce garde-là est global, et blink l'ignore pour les
        -- caractères déclencheurs et le déclenchement manuel (voir
        -- sources/lib/provider/init.lua:114) : `myArrayTest.` affiche donc
        -- toujours la liste des membres d'un coup, et <C-Space> force le menu
        -- où qu'on soit. Remettre 0 pour retrouver le comportement de VSCode,
        -- qui propose dès le 1er caractère.
        min_keyword_length = 2,
        providers = {
          -- Par défaut blink met `fallbacks = { "buffer" }` sur lsp et path :
          -- les mots du fichier ne sont proposés QUE si le LSP ne renvoie
          -- rien. On retire ce repli pour les avoir toujours dans la liste
          -- (ils restent classés après, via leur score_offset = -3).
          -- NB : une table vide ne suffit pas, tbl_deep_extend la fusionnerait
          -- avec la valeur par défaut ; une fonction, elle, l'écrase.
          lsp = {
            fallbacks = function() return {} end,
            max_items = keep_best("lsp"),
            -- Emmet propose une abréviation pour à peu près tout ce qu'on
            -- tape : sur `myArrayTest.po` il lit `.po` comme un sélecteur de
            -- classe et répond `<myArrayTest class="po">`, qui vient
            -- concurrencer `pop` du LSP TypeScript.
            -- blink neutralise déjà le bonus de correspondance exacte
            -- (score_offset = -6, voir sources/lsp/hacks/emmet.lua), mais
            -- seulement pour les clients nommés `emmet_ls` ou
            -- `emmet-language-server` ; nvim-lspconfig, lui, le nomme
            -- `emmet_language_server` et le correctif est donc sauté.
            -- -6 ne suffit de toute façon pas : le matcher Rust ajoute aussi
            -- un bonus de frecency, donc chaque abréviation acceptée par
            -- erreur remonte durablement au-dessus du LSP. D'où deux poids :
            --   * html/css : Emmet EST la source utile, pénalité minimale ;
            --   * ailleurs (jsx/tsx/vue) : il n'est qu'un complément et doit
            --     toujours passer après le LSP du langage, quel que soit son
            --     score. Il reste proposé, mais en fin de liste.
            -- Emmet n'est plus attaché aux .js du tout : voir webdev.lua.
            transform_items = function(_, items)
              local markup = vim.tbl_contains({ "html", "css", "scss", "sass", "less" }, vim.bo.filetype)
              local penalty = markup and 6 or 50
              for _, item in ipairs(items) do
                if item.client_name == "emmet_language_server" then
                  item.score_offset = (item.score_offset or 0) - penalty
                end
              end
              return items
            end,
          },
          path = { fallbacks = function() return {} end },
          -- Puisque buffer et snippets ne sont plus un simple repli (voir
          -- `fallbacks` ci-dessus), ils remontaient dès la 1re lettre et
          -- noyaient les 8 lignes du menu sous des mots du fichier. On leur
          -- demande un préfixe assez long pour être discriminant ; le LSP,
          -- lui, garde le seuil global de 0 pour répondre dès le `.`.
          buffer = { min_keyword_length = 3, max_items = keep_best("buffer") },
          snippets = { min_keyword_length = 2, max_items = keep_best("snippets") },
        },
      },
      keymap = {
        -- Comme dans VSCode : <Tab> valide l'entrée sélectionnée du menu.
        -- select_and_accept ne fait rien si le menu est fermé, la liste
        -- continue alors sur snippet_forward puis sur le <Tab> normal.
        ["<Tab>"] = { "select_and_accept", "snippet_forward", "fallback" },
        -- <CR> reste un simple retour à la ligne, menu ouvert ou non : le
        -- preset "enter" de LazyVim le mappe sur "accept", on garde seulement
        -- "fallback" (qui laisse jouer le <CR> natif et celui d'autopairs).
        -- La validation d'une complétion se fait uniquement au <Tab>.
        ["<CR>"] = { "fallback" },
        -- Comme dans VSCode : <Esc> ferme d'abord le menu sans quitter le mode
        -- insertion ; menu fermé, il retombe sur le <Esc> normal.
        ["<Esc>"] = { "cancel", "fallback" },
        -- Le preset "enter" de LazyVim mappe <S-Tab> sur snippet_backward avec
        -- "fallback", qui ignore les mappings utilisateur. "fallback_to_mappings"
        -- laisse passer le <S-Tab> de config/keymaps.lua (désindenter).
        ["<S-Tab>"] = { "snippet_backward", "fallback_to_mappings" },
      },
    },
  },
}
