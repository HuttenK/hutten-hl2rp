-- Recovered AUTONOMOUS repair puzzle rules; Foundation integration.
--[[
	ЛОГИКА ТРЁХ МИНИ-ИГР РЕМОНТА.

	ЭТОТ ФАЙЛ НАРОЧНО НЕ ЗНАЕТ ПРО ДВИЖОК. Ни энтити, ни сети, ни игрока, ни
	единого вызова из GMod — только `math`, `table` и арифметика. Причина
	практическая: такой файл прогоняется движковым интерпретатором вне игры
	(`tools/luarun.py tools/test_games.lua`) тысячами случайных задач за секунду.
	Проверить генератор кликаньем в игре нельзя — редкие раскладки, на которых
	задача оказывается нерешаемой, вылезут у игрока, а не на тесте.

	Всё, что требует мира — расстояние до узла, удар током, списание детали,
	время удержания клавиши, — живёт в `sv_repair.lua`. Сюда приходят уже готовые
	числа.

	ОТВЕТ НИКОГДА НЕ УЕЗЖАЕТ КЛИЕНТУ. У каждой игры есть `Public(state)`, и
	отправлять клиенту разрешено только его результат: панель, знающая ответ, —
	это чит в первый же день. Тест проверяет это отдельно и по именам полей.

	Игра отвечает на ход таблицей `{ok, verdict, finished, win}`:
	  ok       — ход принят (иначе `verdict` объясняет отказ);
	  verdict  — что произошло, строкой: её показывает панель;
	  finished — задача закрыта, дальше ходов нет;
	  win      — закрыта успешно.
]]

ix = ix or {}
ix.repair = ix.repair or {}
ix.repair.games = ix.repair.games or {}

--- Наименьшее число замеров, которым двоичный поиск закрывает `n` вариантов.
-- Циклом, а не через `math.log`: логарифм на границах степеней двойки даёт
-- 2.9999999 и округляется не туда, а ошибка здесь стоит игроку одного замера.
local function BitsFor(n)
	local bits, span = 0, 1

	while span < n do
		span = span * 2
		bits = bits + 1
	end

	return bits
end

local function Clamp(value, low, high)
	if value < low then return low end
	if value > high then return high end

	return value
end

-- ─────────────────────────────────────────────────────────────────────
-- ИГРА I. ПРОЗВОНКА
-- ─────────────────────────────────────────────────────────────────────

--[[
	Кабельная линия из `count` участков, разделённых муфтами (узлы 0..count, где
	0 — сам щиток). Где-то обрыв. Инженер щупает пары точек: между ними либо есть
	цепь, либо нет, — и по ответам сужает круг.

	Это двоичный поиск, и он выбран не ради «геймплея», а потому что им и ищут
	обрыв на самом деле. Отсюда же и то, чем меряется мастерство: не скоростью
	кликанья, а числом замеров.

	ПОЧЕМУ КЛИЕНТУ ВИДНО, КАКИЕ УЧАСТКИ УЖЕ ИСКЛЮЧЕНЫ. Это не подсказка, а мелок
	в руке: живой человек помечает проверенное на самом кабеле. Прятать от игрока
	то, что он уже узнал сам, значит заставлять его вести записи на бумаге —
	игры в этом нет, есть только раздражение.
]]
local PROBE = {}

PROBE.id = "probe"
PROBE.name = "Прозвонка"

function PROBE:New(opts)
	opts = opts or {}

	local skill = opts.skill or 0
	local count = opts.hard and math.random(7, 9) or math.random(4, 6)

	local state = {
		id = self.id,
		count = count,
		broken = math.random(1, count),
		-- Замеров ровно на двоичный поиск плюс один: слишком точный бюджет
		-- наказывал бы за первый неудачный щуп, слишком щедрый — превратил бы
		-- поиск в перебор.
		budget = BitsFor(count) + 1 + math.min(math.floor(skill / 4), 2),
		possible = {},
		probes = {},
		finished = false,
		win = false
	}

	for i = 1, count do
		state.possible[i] = true
	end

	--[[
		Опытный инженер приходит не на пустое место: один участок он отбрасывает
		сразу, по виду и по тому, что этот кусок меняли месяц назад. Ровно один и
		только начиная с шестого уровня — иначе навык подменял бы собой задачу.
	]]
	if skill >= 6 and count > 2 then
		local free = math.random(1, count - 1)

		if free >= state.broken then
			free = free + 1
		end

		state.possible[free] = false
	end

	return state
end

function PROBE:Public(state)
	local possible = {}

	for i = 1, state.count do
		possible[i] = state.possible[i]
	end

	local probes = {}

	for index, probe in ipairs(state.probes) do
		probes[index] = {a = probe.a, b = probe.b, result = probe.result}
	end

	return {
		id = state.id,
		count = state.count,
		budget = state.budget,
		possible = possible,
		probes = probes,
		finished = state.finished,
		win = state.win
	}
end

--- Сколько участков ещё под подозрением. Нужно и панели, и проверке хода.
local function PossibleCount(state)
	local total = 0

	for i = 1, state.count do
		if state.possible[i] then
			total = total + 1
		end
	end

	return total
end

PROBE.PossibleCount = PossibleCount

function PROBE:Move(state, move)
	if state.finished then
		return {ok = false, verdict = "done"}
	end

	if move.kind == "answer" then
		local segment = tonumber(move.segment)

		if !segment or segment < 1 or segment > state.count
			or segment != math.floor(segment) then
			return {ok = false, verdict = "range"}
		end

		state.finished = true
		state.win = segment == state.broken

		return {
			ok = true,
			verdict = state.win and "fixed" or "wrong",
			finished = true,
			win = state.win
		}
	end

	if move.kind != "probe" then
		return {ok = false, verdict = "unknown"}
	end

	if state.budget <= 0 then
		return {ok = false, verdict = "spent"}
	end

	local a, b = tonumber(move.a), tonumber(move.b)

	if !a or !b or a != math.floor(a) or b != math.floor(b)
		or a < 0 or b > state.count or a >= b then
		return {ok = false, verdict = "range"}
	end

	-- Обрыв «внутри» замера — это участок с номером из (a, b]: участок i лежит
	-- между узлами i-1 и i, поэтому верхняя граница включена, а нижняя нет.
	local inside = a < state.broken and state.broken <= b
	local result = inside and "open" or "closed"

	state.budget = state.budget - 1
	state.probes[#state.probes + 1] = {a = a, b = b, result = result}

	for i = 1, state.count do
		if state.possible[i] then

		local within = a < i and i <= b

		if (inside and !within) or (!inside and within) then
			state.possible[i] = false
		end
		end
	end

	return {ok = true, verdict = result, finished = false, win = false}
end

ix.repair.games[PROBE.id] = PROBE

-- ─────────────────────────────────────────────────────────────────────
-- ИГРА II. ДАВЛЕНИЕ
-- ─────────────────────────────────────────────────────────────────────

--[[
	Три вентиля и манометр. Игрок ВЫСТАВЛЯЕТ вентили как считает нужным, а потом
	даёт ПРОГОН — и только тогда узнаёт, что вышло. Крутить сколько угодно ничего
	не стоит; стоит попытка.

	ПОЧЕМУ НЕ ПОХОДОВО. Живой контур не подкручивают по делению, глядя на стрелку:
	вентили ставят, пускают и смотрят, на чём система встанет. Пакетная подача —
	это то, как балансируют на самом деле, и она же убирает бессмысленное
	щёлканье по делениям ради одного числа.

	БЮДЖЕТ — ЧЕТЫРЕ ПРОГОНА, И ЭТО «РОВНО СТОЛЬКО, СКОЛЬКО НАДО».

	Неизвестных четыре: три веса и база. Стрелка показывает исходное давление
	даром, значит база известна сразу, а каждый прогон, отличающийся от прошлого
	одним вентилем, выдаёт вес этого вентиля. Три прогона на разведку, четвёртый —
	на то, чтобы выставить посчитанное.

	То есть разбор контура и ЕСТЬ задуманный путь, а не дыра в ней. Бюджет
	подобран так, чтобы места хватало ровно на один заход без запаса: сорванный
	клапан отнимает опыт, ошибка в счёте — попытку. Пятый прогон превратил бы это
	в спокойный перебор, третьего не хватило бы и безошибочному.

	Проверено не на глаз: `tools/test_games.lua` играет три тысячи партий
	рассуждающим игроком и печатает долю побед. При платном первом показании она
	была 26% — задача была непроходимой, и это нашёл тест, а не игрок.

	Поэтому же показание не огрубляется: считать по стрелке, которой нельзя
	верить, нельзя вовсе, а весь замысел держится на счёте.

	СОРВАННЫЙ КЛАПАН НЕ КОНЧАЕТ РАБОТУ. Он стравливает давление и возвращает
	вентили в исходное — за то и висит. Стоит это прогона, то есть четверти всей
	попытки: достаточно, чтобы лезть вверх осторожно.
]]
local PRESSURE = {}

PRESSURE.id = "pressure"
PRESSURE.name = "Давление"

local VALVES = 3
local STEPS = 4 -- положения вентиля: 0..4
local SPAN = STEPS + 1
local COMBOS = SPAN * SPAN * SPAN

--- Насколько далеко от допуска показание считается «чуть», а не «сильно».
local NEAR = 10

local function PressureOf(state, valves)
	local total = state.base

	for i = 1, VALVES do
		total = total + state.weights[i] * valves[i]
	end

	return total
end

--[[
	Набор вентилей ходит по сети ОДНИМ числом 0..124.

	Три положения по пять — это ровно одно число в пятеричной записи, и гонять
	вместо него три поля значило бы расширять протокол ради того, что и так
	помещается. Проверка границ при этом обязательна: число приходит от клиента,
	и «125» должно отбиваться, а не превращаться в четвёртое положение.
]]
local function Unpack(code)
	local v3 = code % SPAN
	local v2 = math.floor(code / SPAN) % SPAN
	local v1 = math.floor(code / (SPAN * SPAN)) % SPAN

	return {v1, v2, v3}
end

local function Pack(valves)
	return valves[1] * SPAN * SPAN + valves[2] * SPAN + valves[3]
end

PRESSURE.Unpack = Unpack
PRESSURE.Pack = Pack

--- Приговор по показанию. Порядок важен: срыв перекрывает всё остальное.
local function Verdict(state, pressure)
	if pressure > state.limit then return "burst" end
	if pressure >= state.lo and pressure <= state.hi then return "fixed" end

	if pressure > state.hi then
		return pressure - state.hi <= NEAR and "abovenear" or "above"
	end

	return state.lo - pressure <= NEAR and "belownear" or "below"
end

PRESSURE.Verdict = Verdict

--- Сколько из 125 наборов попадают в допуск. Мера того, насколько задача узкая.
local function Solutions(state)
	local total = 0

	for code = 0, COMBOS - 1 do
		if Verdict(state, PressureOf(state, Unpack(code))) == "fixed" then
			total = total + 1
		end
	end

	return total
end

PRESSURE.Solutions = Solutions

local function Bursts(state)
	local total = 0

	for code = 0, COMBOS - 1 do
		if PressureOf(state, Unpack(code)) > state.limit then
			total = total + 1
		end
	end

	return total
end

PRESSURE.Bursts = Bursts

function PRESSURE:New(opts)
	opts = opts or {}

	local skill = opts.skill or 0

	--[[
		Допуск строится ОТ ЦЕЛИ: сперва выбирается набор вентилей, потом окно
		обводится вокруг его давления. Решение существует по построению, а не по
		удаче — прежняя редакция подбирала окно вслепую и на узкой полосе
		сдавалась, возвращая nil.

		Цикл конечный: бесконечный `while true` в генераторе кладёт сервер молча.
	]]
	local function candidate()
		local state = {
			id = self.id,
			base = math.random(30, 70),
			weights = {},
			valves = {},
			start = {},
			limit = 0,
			lo = 0,
			hi = 0,
			runs = 4,
			reading = nil,
			verdict = nil,
			history = {},
			finished = false,
			win = false
		}

		local used = {}

		for i = 1, VALVES do
			-- Веса разной величины и разного знака: одинаковые сделали бы вентили
			-- взаимозаменяемыми, и понимать было бы нечего.
			local weight

			repeat
				weight = math.random(2, 9) * (math.random(1, 2) == 1 and -1 or 1)
			until !used[weight]

			used[weight] = true

			state.weights[i] = weight
			state.valves[i] = math.random(0, STEPS)
			state.start[i] = state.valves[i]
		end

		local pressure = PressureOf(state, state.valves)

		state.limit = pressure + math.random(16, 34)

		local target = Unpack(math.random(0, COMBOS - 1))
		local goal = PressureOf(state, target)

		if goal > state.limit then return nil end

		local width = math.random(4, 7)

		state.lo = goal - math.random(0, width)
		state.hi = state.lo + width

		if state.hi > state.limit then return nil end

		-- Исходное положение в допуске означает задачу, решённую до первого прогона.
		if Verdict(state, pressure) == "fixed" then return nil end

		--[[
			Плотность решений. Одно-два попадания из ста двадцати пяти — это
			лотерея; тридцать — задача, которую закрывает первый же выставленный
			наугад набор.
		]]
		local solutions = Solutions(state)

		if solutions < 4 or solutions > 18 then return nil end

		-- Больше трети наборов за клапаном превращают пробу в минное поле.
		if Bursts(state) > COMBOS * 0.35 then return nil end

		--[[
			Навык даёт ЗНАНИЕ, а не попытку: мастер помнит, в какую сторону двигает
			один из вентилей этого контура. Лишний прогон вместо этого сломал бы
			равновесие из шапки — пятый прогон превращает задачу в алгебру.
		]]
		if skill >= 5 then
			state.hint = math.random(1, VALVES)
			state.hintUp = state.weights[state.hint] > 0
		end

		--[[
			ПЕРВОЕ ПОКАЗАНИЕ ДАЁТСЯ ДАРОМ.

			Манометр висит на трубе и показывает давление всегда — спрашивать у
			него разрешения не надо, прогон для этого не нужен. А тест показал,
			что без этого задача непроходима: рассуждающий игрок выигрывал 26 раз
			из ста, потому что первый прогон уходил на то, чтобы просто узнать,
			где он стоит. Даровое показание не добавляет попыток, оно возвращает
			ту, что уходила впустую.
		]]
		state.reading = pressure
		state.solutions = solutions

		return state
	end

	for attempt = 1, 80 do
		local state = candidate()
		if state then return state end
	end
	return nil
end

function PRESSURE:Public(state)
	local valves = {}

	for i = 1, VALVES do
		valves[i] = state.valves[i]
	end

	local history = {}

	for index, entry in ipairs(state.history) do
		history[index] = {
			valves = {entry.valves[1], entry.valves[2], entry.valves[3]},
			reading = entry.reading,
			verdict = entry.verdict
		}
	end

	return {
		id = state.id,
		valves = valves,
		reading = state.reading,
		verdict = state.verdict,
		lo = state.lo,
		hi = state.hi,
		limit = state.limit,
		runs = state.runs,
		hint = state.hint,
		hintUp = state.hintUp,
		history = history,
		finished = state.finished,
		win = state.win
	}
end

function PRESSURE:Move(state, move)
	if state.finished then
		return {ok = false, verdict = "done"}
	end

	if move.kind != "run" then
		return {ok = false, verdict = "unknown"}
	end

	if state.runs <= 0 then
		return {ok = false, verdict = "spent"}
	end

	local code = tonumber(move.a)

	if !code or code != math.floor(code) or code < 0 or code >= COMBOS then
		return {ok = false, verdict = "range"}
	end

	local valves = Unpack(code)

	state.valves = valves
	state.runs = state.runs - 1

	local pressure = PressureOf(state, valves)
	local verdict = Verdict(state, pressure)

	state.reading = pressure
	state.verdict = verdict
	state.history[#state.history + 1] = {
		valves = {valves[1], valves[2], valves[3]},
		reading = pressure,
		verdict = verdict
	}

	if verdict == "fixed" then
		state.finished = true
		state.win = true

		return {ok = true, verdict = "fixed", finished = true, win = true}
	end

	--[[
		Сорвало — клапан стравил, вентили вернулись в исходное. Стрелка при этом
		показывает уже сброшенное давление: оставь её стоять на том, что сорвало,
		и игрок читал бы с прибора состояние, которого больше нет.
	]]
	if verdict == "burst" then
		state.valves = {state.start[1], state.start[2], state.start[3]}
		state.reading = PressureOf(state, state.valves)
	end

	if state.runs <= 0 then
		state.finished = true
		state.win = false

		return {ok = true, verdict = verdict, finished = true, win = false}
	end

	return {ok = true, verdict = verdict, finished = false, win = false}
end

ix.repair.games[PRESSURE.id] = PRESSURE

-- ─────────────────────────────────────────────────────────────────────
-- ИГРА III. КРЕПЁЖ
-- ─────────────────────────────────────────────────────────────────────

--[[
	Болты по кругу, тянуть надо НАКРЕСТ: затянул один — следующим идёт
	противоположный, и только потом любой из оставшихся. Затянешь подряд — узел
	перекосит, и всё придётся ослабить и начать заново.

	Это единственная из трёх игр без панели: точки рисуются на самом узле в мире,
	и игрок всё время смотрит на объект, а не в интерфейс. Для работы на высоте
	другой формы и быть не может — ради того, чтобы стоять на лестнице и видеть
	вокруг себя улицу, всё это и затевалось.

	УСИЛИЕ СЧИТАЕТ СЕРВЕР. Сюда приходит уже готовое число: клиент сообщает, что
	начал и что отпустил, а сколько он держал — сервер знает сам по времени между
	этими сообщениями. Присланному клиентом усилию верить нельзя.
]]
local BOLTS = {}

BOLTS.id = "bolts"
BOLTS.name = "Крепёж"

--- Противоположный болт. Круг всегда чётный — иначе «накрест» не определено.
local function Opposite(index, count)
	return (index - 1 + count / 2) % count + 1
end

BOLTS.Opposite = Opposite

function BOLTS:New(opts)
	opts = opts or {}

	local skill = opts.skill or 0
	local count = opts.hard and 6 or 4

	local state = {
		id = self.id,
		count = count,
		lo = {},
		hi = {},
		done = {},
		tight = {},
		lost = 0,
		-- Два сорванных болта узел ещё терпит, третий означает поход за винтами.
		allowed = 2,
		finished = false,
		win = false
	}

	for i = 1, count do
		local low = math.random(45, 68) / 100

		state.lo[i] = low
		state.hi[i] = low + math.random(18, 26) / 100
		state.tight[i] = false
	end

	--[[
		Мастеру видно окно усилия, новичку — нет: он ловит его на ощупь. Это и
		есть обещанное «навык даёт не скорость, а знание»; ускорять полосу здесь
		было бы нечего, она и так секундная.
	]]
	state.showBand = skill >= 5

	return state
end

function BOLTS:Public(state)
	local tight, band = {}, nil

	for i = 1, state.count do
		tight[i] = state.tight[i]
	end

	if state.showBand then
		band = {}

		for i = 1, state.count do
			band[i] = {lo = state.lo[i], hi = state.hi[i]}
		end
	end

	local done = {}

	for index, bolt in ipairs(state.done) do
		done[index] = bolt
	end

	return {
		id = state.id,
		count = state.count,
		tight = tight,
		done = done,
		lost = state.lost,
		allowed = state.allowed,
		band = band,
		finished = state.finished,
		win = state.win
	}
end

--- Какой болт обязан быть следующим, или nil, если подойдёт любой свободный.
local function Required(state)
	if #state.done % 2 == 0 then
		return nil
	end

	return Opposite(state.done[#state.done], state.count)
end

BOLTS.Required = Required

function BOLTS:Move(state, move)
	if state.finished then
		return {ok = false, verdict = "done"}
	end

	if move.kind != "tighten" then
		return {ok = false, verdict = "unknown"}
	end

	local bolt = tonumber(move.bolt)

	if !bolt or bolt != math.floor(bolt) or bolt < 1 or bolt > state.count then
		return {ok = false, verdict = "range"}
	end

	if state.tight[bolt] then
		return {ok = false, verdict = "already"}
	end

	local required = Required(state)

	if required and bolt != required then
		-- Перекос: узел ослаб целиком. Материала это не стоит — только времени,
		-- и это правильная цена за невнимательность.
		state.done = {}

		for i = 1, state.count do
			state.tight[i] = false
		end

		return {ok = true, verdict = "skew", finished = false, win = false}
	end

	local torque = Clamp(tonumber(move.torque) or 0, 0, 1)

	if torque < state.lo[bolt] then
		return {ok = true, verdict = "loose", finished = false, win = false}
	end

	if torque > state.hi[bolt] then
		state.lost = state.lost + 1

		if state.lost > state.allowed then
			state.finished = true
			state.win = false

			return {ok = true, verdict = "stripped", finished = true, win = false}
		end

		return {ok = true, verdict = "strip", finished = false, win = false}
	end

	state.tight[bolt] = true
	state.done[#state.done + 1] = bolt

	if #state.done >= state.count then
		state.finished = true
		state.win = true

		return {ok = true, verdict = "fixed", finished = true, win = true}
	end

	return {ok = true, verdict = "tight", finished = false, win = false}
end

ix.repair.games[BOLTS.id] = BOLTS

-- ─────────────────────────────────────────────────────────────────────

--- Завести задачу выбранной игры. Возвращает состояние либо nil, если генератор
--- не смог (у «Давления» это возможно и обработано вызывающей стороной).
function ix.repair.NewGame(id, opts)
	local game = ix.repair.games[id]

	if !game then return nil end

	return game:New(opts or {})
end

--- Сделать ход. Единственная дверь: `sv_repair.lua` не лезет в состояние сам.
function ix.repair.PlayMove(state, move)
	if type(state) != "table" then
		return {ok = false, verdict = "nostate"}
	end

	local game = ix.repair.games[state.id]

	if !game then
		return {ok = false, verdict = "nogame"}
	end

	if type(move) != "table" then
		return {ok = false, verdict = "nomove"}
	end

	return game:Move(state, move)
end

--- Что из состояния можно показывать. Всё, что уезжает клиенту, идёт отсюда.
function ix.repair.PublicState(state)
	local game = state and ix.repair.games[state.id]

	if !game then return nil end

	return game:Public(state)
end
