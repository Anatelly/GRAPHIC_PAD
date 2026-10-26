-- display.vhd
-- Перенос модуля display из Verilog в VHDL.
-- Quartus Prime Lite 18.1, синтаксис VHDL-93/2008.
--
-- ВАЖНО:
-- 1. LCD-команды, ранее подключавшиеся через lcd_cmd_par.inc, объявлены здесь
--    как константы.
-- 2. LUT RGBSET формируется функцией lut_value(), а не длинным case на 128 строк.
-- 3. Интерфейс и алгоритм двух FSM сохранены, повторяющиеся регистры параметров
--    объединены в массивы для сокращения кода.
-- 4. Чтение регистров LCD удалено; интерфейс предназначен для записи команд/данных.
-- 5. Перед использованием на плате проверьте временные диаграммы в ModelSim:
--    это перенос старого RTL, а не проверенный на конкретной ревизии LCD драйвер.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity display is
    port (
        -- Системная тактовая частота.
        clk              : in  std_logic;
        -- Сброс активным низким уровнем.
        rst_n            : in  std_logic;
        -- Импульс периодического запуска/подсчёта интервалов (~33 мс).
        trigger_33ms     : in  std_logic;
        -- Флаг события обновления кадра для внешней логики.
        frame_update     : out std_logic;

        -- Сигнал, сообщающий внешней логике об активном дисплее.
        -- 1 - дисплей активен, 0 - не активен
        sleep_off        : out std_logic;
        -- Подтверждение обработки слова из буфера изображения.
        data_bvld_ack    : out std_logic;
        -- Запрос обновления полного кадра.
        frame_upd_start  : in  std_logic;
        -- Запрос обновления отдельного пикселя/области.
        single_upd_start : in  std_logic;
        -- Координата X обновляемого пикселя/области (0...511).
        x_coordinate     : in  std_logic_vector(8 downto 0);
        -- Координата Y обновляемого пикселя/области (0...511).
        y_coordinate     : in  std_logic_vector(8 downto 0);
        -- '1' означает, что data_buff содержит валидные данные.
        data_buf_valid   : in  std_logic;
        -- 16-битное слово пикселя из буфера (обычно RGB565).
        data_buff        : in  std_logic_vector(15 downto 0);

        -- Флаг валидности команды, передаваемой в cmd2lcd.
        cmd_valid        : out std_logic;
        -- 8-битный код команды LCD.
        cmd              : out std_logic_vector(7 downto 0);
        -- Количество циклов/элементов для текущей команды.
        cmd_cycle        : out std_logic_vector(15 downto 0);
        -- Флаг валидности слова данных для записи в LCD.
        data_wr_valid    : out std_logic;
        -- 16-битное слово команды/параметра/пикселя для LCD.
        data_wr          : out std_logic_vector(15 downto 0);

        -- Подтверждение записи от модуля cmd2lcd.
        ack_wr           : in  std_logic;
        -- Сигнал завершения текущей команды от cmd2lcd.
        cmd_finish       : in  std_logic;
        -- Сигнал завершения фазы записи от cmd2lcd.
        wrphase_finish   : in  std_logic
    );
end entity display;

architecture rtl of display is

    -- Коды команд LCD, используемые для инициализации и записи.
    constant CMD_NOP    : std_logic_vector(7 downto 0) := x"00"; -- Пустая команда.
    constant CMD_SLPOUT : std_logic_vector(7 downto 0) := x"11"; -- Выход из сна.
    constant CMD_DISPON : std_logic_vector(7 downto 0) := x"29"; -- Включение дисплея.
    constant CMD_CASET  : std_logic_vector(7 downto 0) := x"2A"; -- Диапазон X.
    constant CMD_PASET  : std_logic_vector(7 downto 0) := x"2B"; -- Диапазон Y.
    constant CMD_RAMWR  : std_logic_vector(7 downto 0) := x"2C"; -- Запись пикселей.
    constant CMD_RGBSET : std_logic_vector(7 downto 0) := x"2D"; -- Таблица RGB.
    constant CMD_PIXSET : std_logic_vector(7 downto 0) := x"3A"; -- Формат пикселя.

    -- Состояния автомата DPY, выполняющего отдельную LCD-операцию.
    type dpy_state_t is (
        DPY_IDLE,          -- Ожидание команды.
        DPY_CMD_START,     -- Начало выполнения команды.
        DPY_WRITE_REG,     -- Передача команды-регистра.
        DPY_PAR_OUT,       -- Передача параметров команды.
        DPY_CHK_OUTNUMB,   -- Проверка числа переданных параметров.
        DPY_WRITE_PAT,     -- Подготовка/запуск записи пикселей.
        DPY_READ_BUFF,     -- Получение пикселя из внешнего буфера.
        DPY_CHK_BUFNUMB,   -- Проверка числа обработанных пикселей.
        DPY_NOP,           -- Обработка пустой операции.
        DPY_WRITE_LUT,     -- Запуск передачи таблицы цветов.
        DPY_READ_LUT,      -- Получение очередного элемента таблицы.
        DPY_CHK_LUTNUMB,   -- Проверка числа элементов таблицы.
        DPY_WAIT_FINISH,   -- Ожидание завершения передачи.
        DPY_FINISH         -- Завершение текущей операции.
    );

    -- Состояния автомата PCD, управляющего инициализацией и кадром.
    type pcd_state_t is (
        PCD_IDLE,          -- Начальная инициализация/ожидание.
        PCD_PIXSET,        -- Настройка формата пикселя.
        PCD_SLPOUT,        -- Выход LCD из сна.
        PCD_RGBSET,        -- Загрузка таблицы цветов.
        PCD_DISPON,        -- Включение отображения.
        PCD_WAIT_DELAY,    -- Ожидание временной задержки.
        PCD_DISP_IDLE,     -- Ожидание запроса обновления.
        PCD_CASET,         -- Настройка границ по X.
        PCD_PASET,         -- Настройка границ по Y.
        PCD_RAMWR,         -- Запись данных пикселей.
        PCD_FRAME_END      -- Завершение обновления кадра.
    );

    -- Массив из восьми 16-битных слов параметров.
    type word_array_t is array (1 to 8) of std_logic_vector(15 downto 0);

    -- Текущее состояние автомата DPY.
    signal dpy_sta : dpy_state_t := DPY_IDLE;
    -- Следующее состояние автомата DPY.
    signal dpy_nxt : dpy_state_t := DPY_IDLE;
    -- Текущее состояние автомата PCD.
    signal pcd_sta : pcd_state_t := PCD_IDLE;
    -- Следующее состояние автомата PCD.
    signal pcd_nxt : pcd_state_t := PCD_IDLE;

    -- Однотактовый запрос запуска команды DPY.
    signal cmd_start       : std_logic := '0';
    -- Код текущей команды LCD.
    signal cmd_reg         : std_logic_vector(7 downto 0) := (others => '0');
    -- Количество циклов/элементов текущей команды.
    signal cmd_cycle_reg   : unsigned(15 downto 0) := (others => '0');
    -- Маска валидности параметров, подготовленная для команды.
    signal par_enb_reg     : std_logic_vector(7 downto 0) := (others => '0');
    -- Зарегистрированный набор параметров команды.
    signal par_reg         : word_array_t := (others => (others => '0'));
    -- Текущая маска параметров, ожидающих передачи.
    signal par_enb         : std_logic_vector(7 downto 0) := (others => '0');
    -- Текущий сдвигаемый набор параметров команды.
    signal par             : word_array_t := (others => (others => '0'));
    -- Счётчик переданных параметров/пикселей/элементов LUT.
    signal cmd_cnt         : unsigned(15 downto 0) := (others => '0');
    -- Зафиксированное конечное число циклов команды.
    signal cmd_cycle_end   : unsigned(15 downto 0) := (others => '0');
    -- Внутренний импульс завершения команды DPY.
    signal dpy_cmd_finish  : std_logic := '0';

    -- Счётчик периодических интервалов при инициализации/ожидании.
    signal frame_cnt       : unsigned(7 downto 0) := (others => '0');
    -- Вспомогательный счётчик задержки/времени в состоянии ожидания.
    signal common_cnt      : unsigned(15 downto 0) := (others => '0');
    -- Внутренний флаг запуска отображения.
    -- signal disp_start      : std_logic := '0';
    -- Флаг разрешения работы дисплея после инициализации.
    signal display_enb     : std_logic := '0';
    -- Флаг этапа начальной инициализации.
    signal initial_enb     : std_logic := '0';
    -- Зафиксированный запрос обновления полного кадра.
    signal frame_upd_keep  : std_logic := '0';
    -- Зафиксированный запрос одиночного обновления.
    signal single_upd_keep : std_logic := '0';
    -- Начальная граница X обновляемой области.
    signal sc_addr         : unsigned(15 downto 0) := (others => '0');
    -- Конечная граница X обновляемой области.
    signal ec_addr         : unsigned(15 downto 0) := (others => '0');
    -- Начальная граница Y обновляемой области.
    signal sp_addr         : unsigned(15 downto 0) := (others => '0');
    -- Конечная граница Y обновляемой области.
    signal ep_addr         : unsigned(15 downto 0) := (others => '0');
    -- Флаг завершения передачи таблицы RGB.
    -- signal rgbset_finish   : std_logic := '0';
    -- Флаг завершения этапа включения дисплея.
    -- signal dispon_finish   : std_logic := '0';

    -- Запрос чтения очередного элемента внутренней LUT (не чтение LCD).
    signal lut_read_enb    : std_logic := '0';
    -- Адрес элемента таблицы цветов (0...127).
    signal lut_addr_rd     : unsigned(6 downto 0) := (others => '0');
    -- Флаг валидности подготовленного элемента LUT.
    signal lut_data_valid  : std_logic := '0';
    -- Значение текущего элемента таблицы цветов.
    signal lut_data_buf    : std_logic_vector(7 downto 0) := (others => '0');

    -- Флаг выбора красной тестовой полосы.
    signal red_bg          : std_logic := '0';
    -- Флаг выбора зелёной тестовой полосы.
    signal green_bg        : std_logic := '0';
    -- Флаг выбора синей тестовой полосы.
    signal blue_bg         : std_logic := '0';

    -- -- Внутренний флаг валидности слова данных для LCD.
    -- signal data_wr_valid_i : std_logic := '0';
    -- -- Внутреннее 16-битное слово для записи в LCD.
    -- signal data_wr_i       : std_logic_vector(15 downto 0) := (others => '0');
    -- -- Внутренний флаг валидности команды LCD.
    -- signal cmd_valid_i     : std_logic := '0';
    -- -- Внутренний код команды LCD.
    -- signal cmd_i           : std_logic_vector(7 downto 0) := (others => '0');
    -- -- Внутреннее значение количества циклов команды.
    -- signal cmd_cycle_i     : std_logic_vector(15 downto 0) := (others => '0');
    -- -- Внутреннее подтверждение приёма данных буфера.
    -- signal data_bvld_ack_i : std_logic := '0';
    -- -- Внутренний сигнал отключения режима сна.
    -- signal sleep_off_i     : std_logic := '0';
    -- -- Внутренний флаг события обновления кадра.
    -- signal frame_update_i  : std_logic := '0';

    -- Формирование байта LUT для 128 записей:
    -- R0..R15 и B0..B15 имеют шаг 2; R16..R31 и B16..B31
    -- продолжаются значениями 33..63. Зелёный канал 0..63.
    function lut_value(a : unsigned(6 downto 0)) return std_logic_vector is
        variable n : integer;
        variable v : integer;
    begin
        n := to_integer(a);
        if n < 32 then
            if n < 16 then
                v := n * 2;
            else
                v := (n - 16) * 2 + 33;
            end if;
        elsif n < 96 then
            v := n - 32;
        else
            n := n - 96;
            if n < 16 then
                v := n * 2;
            else
                v := (n - 16) * 2 + 33;
            end if;
        end if;
        return std_logic_vector(to_unsigned(v, 8));
    end function;

begin
    -- -- Выходные порты подключены к внутренним сигналам.
    -- cmd_valid       <= cmd_valid_i;
    -- cmd             <= cmd_i;
    -- cmd_cycle       <= cmd_cycle_i;
    -- data_wr_valid   <= data_wr_valid_i;
    -- data_wr         <= data_wr_i;
    -- data_bvld_ack   <= data_bvld_ack_i;
    -- sleep_off       <= sleep_off_i;
    -- frame_update    <= frame_update_i;

    ---------------------------------------------------------------------------
    -- Функциональные регистры PCD: запросы обновления, таймер и координаты.
    ---------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            frame_upd_keep  <= '0';
            single_upd_keep <= '0';
            display_enb     <= '0';
            initial_enb     <= '0';
            common_cnt      <= (others => '0');
            frame_cnt       <= (others => '0');
            -- disp_start      <= '0';
            sc_addr         <= (others => '0');
            ec_addr         <= (others => '0');
            sp_addr         <= (others => '0');
            ep_addr         <= (others => '0');
            -- rgbset_finish   <= '0';
            -- dispon_finish   <= '0';
        elsif rising_edge(clk) then
            -- Фиксируем запрос полного обновления кадра.
            if frame_upd_start = '1' then
                frame_upd_keep <= '1';
            elsif (pcd_sta = PCD_FRAME_END) and (sp_addr = to_unsigned(319, 16)) then
                frame_upd_keep <= '0';
            end if;

            -- Фиксируем запрос обновления одного пикселя/области.
            if single_upd_start = '1' then
                single_upd_keep <= '1';
            elsif pcd_sta = PCD_FRAME_END then
                single_upd_keep <= '0';
            end if;

            -- Разрешаем дисплей после восьми интервалов trigger_33ms.
            if (pcd_sta = PCD_IDLE) and (frame_cnt = to_unsigned(8, 8)) then
                display_enb <= '1';
            end if;

            if pcd_sta = PCD_IDLE then
                initial_enb <= '1';
            elsif pcd_sta = PCD_DISP_IDLE then
                initial_enb <= '0';
            end if;

            if pcd_sta = PCD_IDLE then
                common_cnt <= common_cnt + 1;
            else
                common_cnt <= (others => '0');
            end if;

            case pcd_sta is
                when PCD_IDLE | PCD_WAIT_DELAY =>
                    if trigger_33ms = '1' then
                        frame_cnt <= frame_cnt + 1;
                    end if;
                when others =>
                    frame_cnt <= (others => '0');
            end case;

            -- disp_start <= trigger_33ms;

            if single_upd_start = '1' or single_upd_keep = '1' then
                sc_addr <= resize(unsigned(x_coordinate), 16);
                ec_addr <= resize(unsigned(x_coordinate), 16);
            else
                sc_addr <= (others => '0');
                ec_addr <= to_unsigned(239, 16);
            end if;

            if frame_upd_start = '1' or frame_upd_keep = '1' then
                if pcd_sta = PCD_FRAME_END then
                    sp_addr <= sp_addr + 1;
                elsif pcd_sta = PCD_DISP_IDLE then
                    sp_addr <= (others => '0');
                end if;
            elsif single_upd_start = '1' then
                sp_addr <= resize(unsigned(y_coordinate), 16);
            end if;

            ep_addr <= sp_addr;

            -- if pcd_sta = PCD_IDLE then
            --     rgbset_finish <= '0';
            -- elsif (pcd_sta = PCD_RGBSET) and (dpy_cmd_finish = '1') then
            --     rgbset_finish <= '1';
            -- end if;

            -- if pcd_sta = PCD_IDLE then
            --     dispon_finish <= '0';
            -- elsif (pcd_sta = PCD_WAIT_DELAY) and (frame_cnt = to_unsigned(3, 8)) then
            --     dispon_finish <= '1';
            -- end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Выбор команды, числа циклов и параметров для каждой LCD-команды.
    ---------------------------------------------------------------------------
    process(cmd_reg, single_upd_start, single_upd_keep, sc_addr, ec_addr, sp_addr, ep_addr)
        variable v_par : word_array_t;
        variable v_enb : std_logic_vector(7 downto 0);
        variable v_cycle : unsigned(15 downto 0);
    begin
        v_cycle := (others => '0');
        v_enb   := (others => '0');
        v_par   := (others => (others => '0'));

        case cmd_reg is
            when CMD_PIXSET =>
                v_cycle := to_unsigned(2, 16);
                v_enb   := "00000001";
                v_par(1):= x"0055";
            when CMD_SLPOUT =>
                v_cycle := to_unsigned(1, 16);
            when CMD_DISPON =>
                v_cycle := to_unsigned(1, 16);
            when CMD_CASET =>
                v_cycle := to_unsigned(5, 16);
                v_enb   := "00001111";
                v_par(1):= x"00" & std_logic_vector(sc_addr(15 downto 8));
                v_par(2):= x"00" & std_logic_vector(sc_addr(7 downto 0));
                v_par(3):= x"00" & std_logic_vector(ec_addr(15 downto 8));
                v_par(4):= x"00" & std_logic_vector(ec_addr(7 downto 0));
            when CMD_PASET =>
                v_cycle := to_unsigned(5, 16);
                v_enb   := "00001111";
                v_par(1):= x"00" & std_logic_vector(sp_addr(15 downto 8));
                v_par(2):= x"00" & std_logic_vector(sp_addr(7 downto 0));
                v_par(3):= x"00" & std_logic_vector(ep_addr(15 downto 8));
                v_par(4):= x"00" & std_logic_vector(ep_addr(7 downto 0));
            when CMD_RAMWR =>
                if single_upd_start = '1' or single_upd_keep = '1' then
                    v_cycle := to_unsigned(2, 16);
                end if;
            when CMD_RGBSET =>
                v_cycle := to_unsigned(129, 16);
            when others =>
                null;
        end case;

        cmd_cycle_reg <= v_cycle;
        par_enb_reg   <= v_enb;
        par_reg       <= v_par;
    end process;

    ---------------------------------------------------------------------------
    -- cmd_start и cmd_reg: переходы в PCD FSM инициируют команды для DPY FSM.
    ---------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            cmd_start <= '0';
            cmd_reg   <= (others => '0');
        elsif rising_edge(clk) then
            cmd_start <= '0';
            case pcd_sta is
                when PCD_IDLE =>
                    if pcd_nxt = PCD_PIXSET then
                        cmd_start <= '1'; cmd_reg <= CMD_PIXSET;
                    end if;
                when PCD_PIXSET =>
                    if pcd_nxt = PCD_SLPOUT then
                        cmd_start <= '1'; cmd_reg <= CMD_SLPOUT;
                    end if;
                when PCD_SLPOUT =>
                    -- После выхода из сна сразу переходим к настройке RGB LUT.
                    if pcd_nxt = PCD_RGBSET then
                        cmd_start <= '1'; cmd_reg <= CMD_RGBSET;
                    end if;
                when PCD_RGBSET =>
                    if pcd_nxt = PCD_DISPON then
                        cmd_start <= '1'; cmd_reg <= CMD_DISPON;
                    end if;
                when PCD_DISP_IDLE =>
                    if pcd_nxt = PCD_CASET then
                        cmd_start <= '1'; cmd_reg <= CMD_CASET;
                    end if;
                when PCD_CASET =>
                    if pcd_nxt = PCD_PASET then
                        cmd_start <= '1'; cmd_reg <= CMD_PASET;
                    end if;
                when PCD_PASET =>
                    if pcd_nxt = PCD_RAMWR then
                        cmd_start <= '1'; cmd_reg <= CMD_RAMWR;
                    end if;
                when PCD_FRAME_END =>
                    if pcd_nxt = PCD_CASET then
                        cmd_start <= '1'; cmd_reg <= CMD_CASET;
                    end if;
                when others =>
                    null;
            end case;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Цветные тестовые полосы в нижней части экрана.
    ---------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            red_bg   <= '0';
            green_bg <= '0';
            blue_bg  <= '0';
        elsif rising_edge(clk) then
            red_bg <= '0'; green_bg <= '0'; blue_bg <= '0';
            if dpy_sta = DPY_READ_BUFF and sp_addr >= to_unsigned(299,16)
                and sp_addr <= to_unsigned(319,16) then
                if cmd_cnt >= to_unsigned(60,16) and cmd_cnt <= to_unsigned(80,16) then
                    red_bg <= '1';
                elsif cmd_cnt >= to_unsigned(110,16) and cmd_cnt <= to_unsigned(130,16) then
                    green_bg <= '1';
                elsif cmd_cnt >= to_unsigned(160,16) and cmd_cnt <= to_unsigned(180,16) then
                    blue_bg <= '1';
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Завершение команды DPY FSM и загрузка числа циклов команды.
    ---------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            cmd_cycle_end  <= (others => '0');
            dpy_cmd_finish <= '0';
        elsif rising_edge(clk) then
            if dpy_sta = DPY_CMD_START then
                cmd_cycle_end <= cmd_cycle_reg;
            elsif dpy_sta = DPY_NOP then
                cmd_cycle_end <= to_unsigned(1,16);
            end if;

            if dpy_sta = DPY_FINISH then
                dpy_cmd_finish <= '1';
            else
                dpy_cmd_finish <= '0';
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Параметры команды: загружаются при cmd_start и сдвигаются по мере отправки.
    ---------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            par_enb <= (others => '0');
            par <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if dpy_sta = DPY_IDLE and cmd_start = '1' then
                par_enb <= par_enb_reg;
                par <= par_reg;
            elsif dpy_sta = DPY_PAR_OUT and data_wr_valid = '0' and par_enb(0) = '1' then
                par_enb <= '0' & par_enb(7 downto 1);
                for i in 1 to 7 loop
                    par(i) <= par(i+1);
                end loop;
                par(8) <= (others => '0');
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Счётчик переданных элементов команды / пикселей / байтов LUT.
    ---------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            cmd_cnt <= (others => '0');
        elsif rising_edge(clk) then
            case dpy_sta is
                when DPY_IDLE =>
                    cmd_cnt <= (others => '0');
                when DPY_CMD_START =>
                    cmd_cnt <= cmd_cnt + 1;
                when DPY_PAR_OUT =>
                    if data_wr_valid = '0' and par_enb(0) = '1' then
                        cmd_cnt <= cmd_cnt + 1;
                    end if;
                when DPY_READ_BUFF =>
                    if data_bvld_ack = '1' then
                        cmd_cnt <= cmd_cnt + 1;
                    end if;
                when DPY_READ_LUT =>
                    if lut_data_valid = '0' then
                        cmd_cnt <= cmd_cnt + 1;
                    end if;
                when others =>
                    null;
            end case;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- LUT: запрос адреса, выставление valid и хранение байта таблицы.
    ---------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            lut_read_enb  <= '0';
            lut_addr_rd   <= (others => '0');
            lut_data_valid<= '0';
            lut_data_buf  <= (others => '0');
        elsif rising_edge(clk) then
            lut_read_enb <= '0';
            if dpy_sta = DPY_CMD_START and cmd_reg = CMD_RGBSET then
                lut_read_enb <= '1';
            elsif dpy_sta = DPY_READ_LUT and lut_data_valid = '0' then
                lut_read_enb <= '1';
            end if;

            if dpy_sta = DPY_IDLE or dpy_sta = DPY_CMD_START then
                lut_addr_rd <= (others => '0');
            elsif lut_read_enb = '1' then
                lut_addr_rd <= lut_addr_rd + 1;
            end if;

            if lut_read_enb = '1' then
                lut_data_valid <= '1';
                lut_data_buf <= lut_value(lut_addr_rd);
            elsif data_wr_valid = '0' and lut_data_valid = '1' then
                lut_data_valid <= '0';
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- DPY FSM: выполнение одной команды (запись регистра, пиксели, LUT, чтение).
    ---------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            dpy_sta <= DPY_IDLE;
        elsif rising_edge(clk) then
            dpy_sta <= dpy_nxt;
        end if;
    end process;

    process(dpy_sta, cmd_start, cmd_reg, cmd_cycle_end, cmd_cnt, par_enb,
            data_wr_valid, data_bvld_ack, wrphase_finish, lut_data_valid,
            cmd_finish)
    begin
        dpy_nxt <= DPY_IDLE;
        case dpy_sta is
            when DPY_IDLE =>
                if cmd_start = '1' then 
                    dpy_nxt <= DPY_CMD_START; 
                else 
                    dpy_nxt <= DPY_IDLE;
                end if;
            when DPY_CMD_START =>
                case cmd_reg is
                    when CMD_PIXSET | CMD_SLPOUT | CMD_DISPON | CMD_CASET | CMD_PASET =>
                        dpy_nxt <= DPY_WRITE_REG;
                    when CMD_RAMWR  => 
                        dpy_nxt <= DPY_WRITE_PAT;
                    when CMD_RGBSET => 
                        dpy_nxt <= DPY_WRITE_LUT;
                    when others => 
                        dpy_nxt <= DPY_IDLE;
                end case;
            when DPY_WRITE_REG =>
                if cmd_cycle_end = to_unsigned(1,16) then 
                    dpy_nxt <= DPY_CHK_OUTNUMB;
                else 
                    dpy_nxt <= DPY_PAR_OUT;
                end if;
            when DPY_PAR_OUT =>
                if data_wr_valid = '0' and par_enb(0) = '1' then
                    dpy_nxt <= DPY_CHK_OUTNUMB;
                else 
                    dpy_nxt <= DPY_PAR_OUT; 
                end if;
            when DPY_CHK_OUTNUMB =>
                if cmd_cnt = cmd_cycle_end then 
                    dpy_nxt <= DPY_WAIT_FINISH;
                else 
                    dpy_nxt <= DPY_PAR_OUT;
                end if;
            when DPY_WRITE_PAT => 
                dpy_nxt <= DPY_READ_BUFF;
            when DPY_READ_BUFF =>
                if data_bvld_ack = '1' then 
                    dpy_nxt <= DPY_CHK_BUFNUMB;
                else 
                    dpy_nxt <= DPY_READ_BUFF; 
                end if;
            when DPY_CHK_BUFNUMB =>
                if cmd_cnt = cmd_cycle_end or cmd_cnt = to_unsigned(241,16) then
                    if wrphase_finish = '1' then
                        dpy_nxt <= DPY_NOP;
                    else
                        dpy_nxt <= DPY_CHK_BUFNUMB; 
                    end if;
                else 
                    dpy_nxt <= DPY_READ_BUFF; 
                end if;
            when DPY_NOP => 
                dpy_nxt <= DPY_WAIT_FINISH;
            when DPY_WRITE_LUT => 
                dpy_nxt <= DPY_READ_LUT;
            when DPY_READ_LUT =>
                if lut_data_valid = '0' then 
                    dpy_nxt <= DPY_CHK_LUTNUMB;
                else 
                    dpy_nxt <= DPY_READ_LUT; 
                end if;
            when DPY_CHK_LUTNUMB =>
                if cmd_cnt = to_unsigned(129,16) then 
                    dpy_nxt <= DPY_WAIT_FINISH;
                else 
                    dpy_nxt <= DPY_READ_LUT;
                end if;
            when DPY_WAIT_FINISH =>
                if cmd_finish = '1' then 
                    dpy_nxt <= DPY_FINISH;
                else 
                    dpy_nxt <= DPY_WAIT_FINISH; 
                end if;
            when DPY_FINISH => 
                dpy_nxt <= DPY_IDLE;
            when others => 
                dpy_nxt <= DPY_IDLE;
        end case;
    end process;

    ---------------------------------------------------------------------------
    -- PCD FSM: инициализация дисплея и последовательное обновление строк.
    ---------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            pcd_sta <= PCD_IDLE;
        elsif rising_edge(clk) then
            pcd_sta <= pcd_nxt;
        end if;
    end process;

    process(pcd_sta, display_enb, initial_enb, dpy_cmd_finish,
            frame_cnt, frame_upd_start, single_upd_start,
            frame_upd_keep, single_upd_keep, sp_addr)
    begin
        pcd_nxt <= PCD_IDLE;
        case pcd_sta is
            when PCD_IDLE =>
                if display_enb = '1' then
                    if initial_enb = '1' then
                        pcd_nxt <= PCD_PIXSET;
                    else 
                        pcd_nxt <= PCD_DISP_IDLE; 
                    end if;
                else 
                    pcd_nxt <= PCD_IDLE; 
                end if;
            when PCD_PIXSET =>
                if dpy_cmd_finish = '1' then 
                    pcd_nxt <= PCD_SLPOUT; 
                else 
                    pcd_nxt <= PCD_PIXSET; 
                end if;
            when PCD_SLPOUT =>
                if dpy_cmd_finish = '1' then 
                    pcd_nxt <= PCD_RGBSET; 
                else 
                    pcd_nxt <= PCD_SLPOUT;
                end if;
            when PCD_RGBSET =>
                if dpy_cmd_finish = '1' then 
                    pcd_nxt <= PCD_DISPON; 
                else 
                    pcd_nxt <= PCD_RGBSET; 
                end if;
            when PCD_DISPON =>
                if dpy_cmd_finish = '1' then 
                    pcd_nxt <= PCD_WAIT_DELAY; 
                else 
                    pcd_nxt <= PCD_DISPON; 
                end if;
            when PCD_WAIT_DELAY =>
                if frame_cnt = to_unsigned(3,8) then 
                    pcd_nxt <= PCD_DISP_IDLE;
                else 
                    pcd_nxt <= PCD_WAIT_DELAY; 
                end if;
            when PCD_DISP_IDLE =>
                if frame_upd_start = '1' or single_upd_start = '1' then 
                    pcd_nxt <= PCD_CASET;
                else 
                    pcd_nxt <= PCD_DISP_IDLE; 
                end if;
            when PCD_CASET =>
                if dpy_cmd_finish = '1' then 
                    pcd_nxt <= PCD_PASET; 
                else 
                    pcd_nxt <= PCD_CASET; 
                end if;
            when PCD_PASET =>
                if dpy_cmd_finish = '1' then 
                    pcd_nxt <= PCD_RAMWR; 
                else 
                    pcd_nxt <= PCD_PASET; 
                end if;
            when PCD_RAMWR =>
                if dpy_cmd_finish = '1' then 
                    pcd_nxt <= PCD_FRAME_END; 
                else 
                    pcd_nxt <= PCD_RAMWR; 
                end if;
            when PCD_FRAME_END =>
                if (frame_upd_keep = '1' and sp_addr = to_unsigned(319,16))
                    or single_upd_keep = '1' then
                    pcd_nxt <= PCD_DISP_IDLE;
                else 
                    pcd_nxt <= PCD_CASET; 
                end if;
            when others => 
                pcd_nxt <= PCD_IDLE;
        end case;
    end process;

    ---------------------------------------------------------------------------
    -- Буферный интерфейс: запрос/подтверждение пиксельных данных и sleep_off.
    ---------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            sleep_off     <= '0';
            data_bvld_ack <= '0';
        elsif rising_edge(clk) then
            -- Считаем дисплей активным после завершения команды DISPON.
            -- Флаг остаётся установленным до сброса.
            if pcd_sta = PCD_DISPON and dpy_cmd_finish = '1' then
                sleep_off <= '1';
            end if;

            if dpy_sta = DPY_READ_BUFF and data_wr_valid = '0' and data_buf_valid = '1' then
                data_bvld_ack <= '1';
            else 
                data_bvld_ack <= '0'; 
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Выходные сигналы для cmd2lcd.
    ---------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            cmd_valid     <= '0';
            cmd           <= (others => '0');
            cmd_cycle     <= (others => '0');
            data_wr_valid <= '0';
            data_wr       <= (others => '0');
        elsif rising_edge(clk) then
            if dpy_sta = DPY_CMD_START or dpy_sta = DPY_NOP then
                cmd_valid <= '1';
            else 
                cmd_valid <= '0'; 
            end if;

            if dpy_sta = DPY_CMD_START then
                cmd <= cmd_reg;
            elsif dpy_sta = DPY_NOP then
                cmd <= CMD_NOP;
            end if;

            if dpy_sta = DPY_CMD_START then
                if cmd_reg = CMD_RAMWR then 
                    cmd_cycle <= (others => '0');
                else 
                    cmd_cycle <= std_logic_vector(cmd_cycle_reg); 
                end if;
            elsif dpy_sta = DPY_NOP then
                cmd_cycle <= std_logic_vector(to_unsigned(1,16));
            end if;

            if ack_wr = '1' then
                data_wr_valid <= '0'; --сброс флага валидности
            elsif dpy_sta = DPY_PAR_OUT and data_wr_valid = '0' and par_enb(0) = '1' then
                data_wr_valid <= '1';
            elsif dpy_sta = DPY_READ_BUFF and data_wr_valid = '0' and data_buf_valid = '1' then
                data_wr_valid <= '1';
            elsif dpy_sta = DPY_READ_LUT and data_wr_valid = '0' and lut_data_valid = '1' then
                data_wr_valid <= '1';
            end if;

            if dpy_sta = DPY_PAR_OUT and data_wr_valid = '0' and par_enb(0) = '1' then
                data_wr <= par(1);
            elsif dpy_sta = DPY_READ_BUFF and data_wr_valid = '0' and data_buf_valid = '1' then
                --тестовые полосы--
                if red_bg = '1' then
                    data_wr <= x"F800";
                elsif green_bg = '1' then 
                    data_wr <= x"07E0";
                elsif blue_bg = '1' then 
                    data_wr <= x"001F";
                --тестовые полосы--
                else 
                    data_wr <= data_buff; 
                end if;
            elsif dpy_sta = DPY_READ_LUT and data_wr_valid = '0' and lut_data_valid = '1' then
                data_wr <= x"00" & lut_data_buf;
            end if;

        end if;
    end process;

    ---------------------------------------------------------------------------
    -- frame_update: импульс по окончании полного кадра или одиночного обновления.
    ---------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            frame_update <= '0';
        elsif rising_edge(clk) then
            if pcd_sta = PCD_FRAME_END and
               ((frame_upd_keep = '1' and sp_addr = to_unsigned(319,16))
                or single_upd_keep = '1') then
                frame_update <= '1';
            else
                frame_update <= '0';
            end if;
        end if;
    end process;

end architecture rtl;
