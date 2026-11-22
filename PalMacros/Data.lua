-- Pal Macros: данные о заклинаниях, шаблоны макросов, фразы и приоритеты благословений.
local _, ns = ...

-- Шаблоны макросов (kind):
--   bless     - благословение: мышь -> цель -> себя, + фраза в чат
--   help      - помощь: мышь -> дружеская цель -> себя
--   helpother - помощь без себя: мышь -> дружеская цель
--   dead      - воскрешение: мёртвый под мышью -> мёртвая цель
--   urgent    - срочная помощь (/stopcasting): мышь -> цель -> себя, Alt снимает эффект с себя
--   dual      - Шок небес: лечит союзника / бьёт врага (мышь -> цель -> себя)
--   attack    - атака: если нет живой вражеской цели - взять ближайшего врага, + автоатака
--   control   - контроль (оглушение/страх/покаяние): враг под мышью -> цель -> ближайший враг, без автоатаки
--   self      - на себя / без цели
--   toggle    - на себя, Alt снимает эффект (Божественный щит, Праведное неистовство)
--   mount     - ездовое: повторное нажатие спешивает
-- Порядок групп в окне.
ns.GROUPS = {
  { id = "bless",   title = "Благословения (1 час)" },
  { id = "heal",    title = "Исцеление и помощь" },
  { id = "attack",  title = "Атака и контроль" },
  { id = "seal",    title = "Печати" },
  { id = "aura",    title = "Ауры" },
  { id = "defense", title = "Защита и прочее" },
  { id = "other",   title = "Новые / нераспознанные заклинания" },
}

-- key, id (ранг 1 в Classic; имя берётся из игры на языке клиента), en (запасное имя), kind, group, label (имя макроса)
ns.SPELLS = {
  -- Благословения
  { key = "might",     id = 19740, en = "Blessing of Might",      kind = "bless", group = "bless", label = "Могущество" },
  { key = "wisdom",    id = 19742, en = "Blessing of Wisdom",     kind = "bless", group = "bless", label = "Мудрость" },
  { key = "kings",     id = 20217, en = "Blessing of Kings",      kind = "bless", group = "bless", label = "Короли" },
  { key = "salvation", id = 1038,  en = "Blessing of Salvation",  kind = "bless", group = "bless", label = "Спасение" },
  { key = "light",     id = 19977, en = "Blessing of Light",      kind = "bless", group = "bless", label = "Свет" },
  { key = "sanctuary", id = 20911, en = "Blessing of Sanctuary",  kind = "bless", group = "bless", label = "Святилище" },
  { key = "gmight",     id = 25782, en = "Greater Blessing of Might",     kind = "bless", group = "bless", label = "В.Могущ", base = "might" },
  { key = "gwisdom",    id = 25894, en = "Greater Blessing of Wisdom",    kind = "bless", group = "bless", label = "В.Мудр",  base = "wisdom" },
  { key = "gkings",     id = 25898, en = "Greater Blessing of Kings",     kind = "bless", group = "bless", label = "В.Короли", base = "kings" },
  { key = "gsalvation", id = 25895, en = "Greater Blessing of Salvation", kind = "bless", group = "bless", label = "В.Спас",  base = "salvation" },
  { key = "glight",     id = 25890, en = "Greater Blessing of Light",     kind = "bless", group = "bless", label = "В.Свет",  base = "light" },
  { key = "gsanctuary", id = 25899, en = "Greater Blessing of Sanctuary", kind = "bless", group = "bless", label = "В.Свят",  base = "sanctuary" },

  -- Исцеление и помощь
  { key = "holylight",  id = 635,   en = "Holy Light",             kind = "help",      group = "heal", label = "Свет небес" },
  { key = "flash",      id = 19750, en = "Flash of Light",         kind = "help",      group = "heal", label = "Вспышка" },
  { key = "holyshock",  id = 20473, en = "Holy Shock",             kind = "dual",      group = "heal", label = "Шок небес" },
  { key = "layonhands", id = 633,   en = "Lay on Hands",           kind = "urgent",    group = "heal", label = "Возл.рук" },
  { key = "cleanse",    id = 4987,  en = "Cleanse",                kind = "help",      group = "heal", label = "Очищение" },
  { key = "purify",     id = 1152,  en = "Purify",                 kind = "help",      group = "heal", label = "Омовение" },
  { key = "bop",        id = 1022,  en = "Blessing of Protection", kind = "urgent",    group = "heal", label = "Защита" },
  { key = "freedom",    id = 1044,  en = "Blessing of Freedom",    kind = "urgent",    group = "heal", label = "Свобода" },
  { key = "sacrifice",  id = 6940,  en = "Blessing of Sacrifice",  kind = "helpother", group = "heal", label = "Жертва" },
  { key = "intervene",  id = 19752, en = "Divine Intervention",    kind = "helpother", group = "heal", label = "Вмешател." },
  { key = "redemption", id = 7328,  en = "Redemption",             kind = "dead",      group = "heal", label = "Искупление" },

  -- Атака и контроль
  { key = "judgement",  id = 20271, en = "Judgement",              kind = "attack",  group = "attack", label = "Правосудие" },
  { key = "holystrike", id = nil,   en = "Holy Strike",            kind = "attack",  group = "attack", label = "Удар Света" },
  { key = "crusader",   id = 35395, en = "Crusader Strike",        kind = "attack",  group = "attack", label = "Удар воина" },
  { key = "exorcism",   id = 879,   en = "Exorcism",               kind = "attack",  group = "attack", label = "Экзорцизм" },
  { key = "wrath",      id = 24275, en = "Hammer of Wrath",        kind = "attack",  group = "attack", label = "Мол.гнева" },
  { key = "avenger",    id = 31935, en = "Avenger's Shield",       kind = "attack",  group = "attack", label = "Щит мстит." },
  { key = "hoj",        id = 853,   en = "Hammer of Justice",      kind = "control", group = "attack", label = "Мол.правос" },
  { key = "repentance", id = 20066, en = "Repentance",             kind = "control", group = "attack", label = "Покаяние" },
  { key = "turnundead", id = 2878,  en = "Turn Undead",            kind = "control", group = "attack", label = "Изгн.нежит" },
  { key = "consecrate", id = 26573, en = "Consecration",           kind = "self",    group = "attack", label = "Освящение" },
  { key = "holywrath",  id = 2812,  en = "Holy Wrath",             kind = "self",    group = "attack", label = "Гнев небес" },

  -- Печати (в Forever Правосудие больше не снимает печать)
  { key = "sor",  id = 20154, en = "Seal of Righteousness", kind = "self", group = "seal", label = "П.праведн" },
  { key = "sotc", id = 21082, en = "Seal of the Crusader",  kind = "self", group = "seal", label = "П.воина" },
  { key = "soj",  id = 20164, en = "Seal of Justice",       kind = "self", group = "seal", label = "П.справедл" },
  { key = "sol",  id = 20165, en = "Seal of Light",         kind = "self", group = "seal", label = "П.света" },
  { key = "sow",  id = 20166, en = "Seal of Wisdom",        kind = "self", group = "seal", label = "П.мудрости" },
  { key = "soc",  id = 20375, en = "Seal of Command",       kind = "self", group = "seal", label = "П.повелен" },
  { key = "sof",  id = nil,   en = "Seal of Fury",          kind = "self", group = "seal", label = "П.ярости" },

  -- Ауры
  { key = "devotion",      id = 465,   en = "Devotion Aura",                kind = "self", group = "aura", label = "А.благочест" },
  { key = "retribution",   id = 7294,  en = "Retribution Aura",             kind = "self", group = "aura", label = "А.возмезд" },
  { key = "concentration", id = 19746, en = "Concentration Aura",           kind = "self", group = "aura", label = "А.сосредот" },
  { key = "shadowres",     id = 19876, en = "Shadow Resistance Aura",       kind = "self", group = "aura", label = "А.тьмы" },
  { key = "frostres",      id = 19888, en = "Frost Resistance Aura",        kind = "self", group = "aura", label = "А.льда" },
  { key = "fireres",       id = 19891, en = "Fire Resistance Aura",         kind = "self", group = "aura", label = "А.огня" },
  { key = "sanctity",      id = 20218, en = "Sanctity Aura",                kind = "self", group = "aura", label = "А.святости" },

  -- Защита и прочее
  { key = "divineshield", id = 642,   en = "Divine Shield",       kind = "toggle", group = "defense", label = "Бож.щит" },
  { key = "divineprot",   id = 498,   en = "Divine Protection",   kind = "toggle", group = "defense", label = "Бож.защита" },
  { key = "bulwark",      id = nil,   en = "Templar's Bulwark",   kind = "self",   group = "defense", label = "Бастион" },
  { key = "holyshield",   id = 20925, en = "Holy Shield",         kind = "self",   group = "defense", label = "Щит небес" },
  { key = "rfury",        id = 25780, en = "Righteous Fury",      kind = "toggle", group = "defense", label = "Пр.неистов" },
  { key = "favor",        id = 20216, en = "Divine Favor",        kind = "self",   group = "defense", label = "Бож.одобр" },
  { key = "senseundead",  id = 5502,  en = "Sense Undead",        kind = "self",   group = "defense", label = "Чутьё нежит" },
  { key = "warhorse",     id = 13819, en = "Summon Warhorse",     kind = "mount",  group = "defense", label = "Конь" },
  { key = "charger",      id = 23214, en = "Summon Charger",      kind = "mount",  group = "defense", label = "Боевой конь" },
}

-- Готовые комбинированные макросы (появляются, когда изучено нужное заклинание).
ns.COMBOS = {
  {
    key = "combo_bubblehearth", requires = "divineshield", group = "defense", label = "Щит+Камень",
    desc = "Божественный щит, второе нажатие - Камень возвращения",
    build = function(n) return "#showtooltip " .. n.divineshield .. "\n/cast " .. n.divineshield .. "\n/use item:6948" end,
  },
}

-- Кнопка «Бой»: рекомендуемая очередь (сверху — важнее). Макрос пробует строки по порядку:
-- если заклинание на перезарядке, нет печати или цель не подходит — берётся следующее.
-- "@new" — атакующие заклинания Forever, которых нет в таблице (например, Удар Света в русском клиенте).
ns.FIGHT_RECOMMENDED = { "judgement", "holystrike", "@new", "crusader", "wrath", "exorcism", "avenger" }

-- Описания шаблонов для окна.
ns.KIND_DESC = {
  bless     = "мышь > цель > себя, фраза в чат",
  help      = "мышь > цель > себя",
  helpother = "мышь > дружеская цель",
  dead      = "мёртвый под мышью > цель",
  urgent    = "прерывает каст; мышь > цель > себя; Alt — снять с себя",
  dual      = "лечит союзника или бьёт врага; мышь > цель > себя",
  attack    = "нет цели — берёт ближайшего врага, автоатака",
  control   = "враг под мышью > цель > ближайший враг",
  self      = "без цели",
  toggle    = "Alt — снять эффект",
  mount     = "повторное нажатие — спешиться",
  generic_harm = "нет цели — берёт ближайшего врага",
  generic_help = "мышь > цель > себя",
  generic   = "обычное применение",
}

-- Длительные благословения, для которых есть фразы.
ns.BLESS_KEYS = { "might", "wisdom", "kings", "salvation", "light", "sanctuary" }
ns.BLESS_TITLES = {
  might = "Могущество", wisdom = "Мудрость", kings = "Короли",
  salvation = "Спасение", light = "Свет", sanctuary = "Святилище", none = "—",
}

-- Фразы по умолчанию. Подстановки: {name} - имя цели, {class} - класс цели, {spell} - название заклинания.
ns.DEFAULT_PHRASES = {
  ru = {
    might = {
      "Клянусь бородой предков, {name}! Сила гор теперь в твоих руках!",
      "Держи, {name}! Бей так, чтоб наковальня треснула!",
      "{name}, пусть твой удар будет тяжелее кузнечного молота!",
      "Свет и сталь, {name}! Теперь ты крепок, как бочонок тёмного эля!",
      "Ха! {name}, с таким благословением хоть тролля голыми руками!",
    },
    wisdom = {
      "{name}, пусть мысль твоя течёт, как эль из бочонка, — без конца!",
      "Мудрость предков Стальгорна с тобой, {name}!",
      "Держи, {name}! Голова светлее — заклинания крепче!",
      "Даже руны поддаются терпеливым, {name}. Да не иссякнет твоя мана!",
      "{name}, пей мудрость, как эль, — большими глотками!",
    },
    kings = {
      "Во имя Трёх Молотов, {name}! Будь крепок, как сами горы!",
      "{name}, благословение королей! Сам тан бы позавидовал!",
      "Камень, сталь и Свет — всё теперь в тебе, {name}!",
      "Стой прямо, {name}! Теперь ты крепче ворот Стальгорна!",
      "Клянусь бородой, {name}, теперь ты сильнее во всём!",
    },
    salvation = {
      "{name}, тише, тише... пусть враг смотрит на того, кто со щитом!",
      "Не горячись, {name}! Свет укроет тебя от вражьего гнева.",
      "Держись за спиной танка, {name}, а за остальным присмотрит Свет!",
      "{name}, пусть чудища тебя не замечают, как гоблин не замечает скидок!",
    },
    light = {
      "Да согреет тебя Свет, {name}, как горн в кузне!",
      "{name}, пусть каждое исцеление ложится на тебя вдвое теплее!",
      "Свет с тобой, {name}! Грейся, как у очага в таверне!",
    },
    sanctuary = {
      "{name}, стой за мной — это место под защитой Света!",
      "Святилище с тобой, {name}! Пусть враги разбивают лбы о камень!",
      "Будь скалой Дун Морога, {name}! Пусть удары отскакивают!",
    },
  },
  en = {
    might = {
      "By me beard, {name}! The strength o' the mountains be yours!",
      "Hit 'em like a forge hammer, {name}!",
      "Light an' steel, {name}! Go crack some skulls!",
      "Ha! With this, {name}, ye could wrestle a troll bare-handed!",
      "Swing true, {name}, an' make the anvil ring!",
    },
    wisdom = {
      "May yer mind flow like ale from a keg, {name} — never runnin' dry!",
      "The wisdom o' Ironforge be with ye, {name}!",
      "Clear head, strong spells, {name}! Off ye go!",
      "Even runes yield to the patient, {name}. Keep yer mana flowin'!",
      "Drink deep o' the Light, {name}, like a good stout!",
    },
    kings = {
      "By the Three Hammers, {name}! Stand strong as the mountains!",
      "A blessin' fit for a king, {name}! Even a thane'd be jealous!",
      "Stone, steel an' Light be in ye now, {name}!",
      "Stand tall, {name}! Ye're sturdier than the gates o' Ironforge!",
      "By me beard, {name}, ye're stronger in every way now!",
    },
    salvation = {
      "Easy now, {name}! Let the beasties stare at the one with the shield!",
      "Keep yer temper, {name} — the Light hides ye from their wrath.",
      "Stay behind the tank, {name}, an' the Light'll mind the rest!",
      "{name}, may the monsters ignore ye like a goblin ignores a fair price!",
    },
    light = {
      "May the Light warm ye like a forge, {name}!",
      "Every heal on ye burns brighter now, {name}!",
      "The Light be with ye, {name}! Warm yerself like by a tavern hearth!",
    },
    sanctuary = {
      "Stand behind me, {name} — this ground is holy!",
      "Let 'em break their teeth on ye, {name}!",
      "Be a rock o' Dun Morogh, {name}! Let the blows bounce off!",
    },
  },
}

-- Приоритет благословений по классу цели (первое изученное из списка).
-- Forever: Короли - базовое с 20 уровня, Могущество ослаблено, все благословения длятся 1 час.
ns.CLASS_ORDER = { "WARRIOR", "ROGUE", "HUNTER", "PALADIN", "SHAMAN", "DRUID", "PRIEST", "MAGE", "WARLOCK", "OTHER" }
ns.DEFAULT_PRIO = {
  WARRIOR = { "might", "kings" },
  ROGUE   = { "might", "kings" },
  HUNTER  = { "might", "kings" },
  PALADIN = { "kings", "wisdom" },
  SHAMAN  = { "kings", "wisdom" },
  DRUID   = { "kings", "wisdom" },
  PRIEST  = { "wisdom", "kings" },
  MAGE    = { "wisdom", "kings" },
  WARLOCK = { "wisdom", "kings" },
  OTHER   = { "kings", "might" },   -- питомцы, NPC
}
ns.CLASS_NAMES_FALLBACK = {
  WARRIOR = "Воин", ROGUE = "Разбойник", HUNTER = "Охотник", PALADIN = "Паладин", SHAMAN = "Шаман",
  DRUID = "Друид", PRIEST = "Жрец", MAGE = "Маг", WARLOCK = "Чернокнижник", OTHER = "Питомцы и NPC",
}
