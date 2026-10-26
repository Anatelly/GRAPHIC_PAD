-- pat_update.vhd
-- Генератор полноэкранных цветовых тестовых кадров для LCD.
-- Логика тачпада и чтения координат удалена.
-- Синтаксис: VHDL-2008, библиотека IEEE numeric_std.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rgb_test is
    generic (
        -- Число интервалов trigger_33ms перед обновлением кадра
        -- для зелёного и синего фонов. Для ускоренной симуляции задайте 1.
        UPD_STR_CNT_END : unsigned(5 downto 0) := to_unsigned(32, 6)
    );
    port (
        -- Тактовый сигнал и сброс активным низким уровнем.
        clk             : in  std_logic;
        rst_n           : in  std_logic;

        -- Периодический импульс с интервалом около 33 мс.
        trigger_33ms    : in  std_logic;

        -- Разрешение работы дисплея.
        sleep_off       : in  std_logic;

        -- Интерфейс обновления кадрового буфера.
        frame_upd_start : out std_logic;
        write_enb       : out std_logic;
        data_buff       : out std_logic_vector(15 downto 0);
        frame_end       : in  std_logic;
        write_enb_ack   : in  std_logic
    );
end entity rgb_test;

architecture rtl of rgb_test is

    -- Состояния формирования красного, зелёного и синего кадров.
    type pat_state_t is (
        PAT_IDLE,
        PAT_R_PAT_S, PAT_R_PAT, PAT_R_PAT_F, --Запуск и передача красного кадра
        PAT_G_PAT_S, PAT_G_PAT, PAT_G_PAT_F, --Запуск и передача зелёного кадра
        PAT_B_PAT_S, PAT_B_PAT, PAT_B_PAT_F  --Запуск и передача синего кадра
    );

    signal pat_sta, pat_nxt : pat_state_t := PAT_IDLE;

    -- Счётчик интервалов перед запуском очередного кадра.
    signal upd_str_cnt : unsigned(5 downto 0) := (others => '0');

    -- Внутренние сигналы управления кадровым буфером.
    signal update_start       : std_logic := '0';
    signal pat_enb            : std_logic := '0';
    signal common_cnt         : unsigned(15 downto 0) := (others => '0');
    -- signal frame_upd_start_i  : std_logic := '0';
    -- signal write_enb_i        : std_logic := '0';
    -- signal data_buff_i        : std_logic_vector(15 downto 0) := (others => '0');

begin

    -- Подключение зарегистрированных сигналов к выходам.
    -- frame_upd_start <= frame_upd_start_i;
    -- write_enb       <= write_enb_i;
    -- data_buff       <= data_buff_i;

    -- Разрешаем запуск генератора после начальной задержки,
    -- если дисплей не находится в режиме сна.
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            pat_enb <= '0';
        elsif rising_edge(clk) then
            if pat_sta = PAT_IDLE
               and common_cnt = to_unsigned(16#0080#, common_cnt'length) --128
               and sleep_off = '1' then
                pat_enb <= '1';
            end if;
        end if;
    end process;

    -- Счётчик задержки в состоянии ожидания.
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            common_cnt <= (others => '0');
        elsif rising_edge(clk) then
            if pat_sta = PAT_IDLE then
                common_cnt <= common_cnt + 1;
            else
                common_cnt <= (others => '0');
            end if;
        end if;
    end process;

    -- Ожидаем заданное количество интервалов перед началом кадра.
    -- Для первого (красного) кадра оставлено исходное значение 4.
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            update_start <= '0';
        elsif rising_edge(clk) then
            case pat_sta is
                when PAT_R_PAT_S =>
                    if upd_str_cnt = to_unsigned(4, upd_str_cnt'length) then
                        update_start <= '1';
                    else
                        update_start <= '0';
                    end if;

                when PAT_G_PAT_S | PAT_B_PAT_S =>
                    if upd_str_cnt = UPD_STR_CNT_END then
                        update_start <= '1';
                    else
                        update_start <= '0';
                    end if;

                when others =>
                    update_start <= '0';
            end case;
        end if;
    end process;

    -- Считаем импульсы trigger_33ms, пока ожидаем запуск кадра.
    process(trigger_33ms, rst_n)
    begin
        if rst_n = '0' then
            upd_str_cnt <= (others => '0');
        elsif rising_edge(trigger_33ms) then
            case pat_sta is
                when PAT_R_PAT_S | PAT_G_PAT_S | PAT_B_PAT_S =>
                    if (pat_sta = PAT_R_PAT_S and
                        upd_str_cnt < to_unsigned(4, upd_str_cnt'length)) or
                       (pat_sta /= PAT_R_PAT_S and
                        upd_str_cnt < UPD_STR_CNT_END) then
                        upd_str_cnt <= upd_str_cnt + 1;
                    end if;
                when others =>
                    upd_str_cnt <= (others => '0');
            end case;
        end if;
    end process;

    -- Регистр текущего состояния автомата.
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            pat_sta <= PAT_IDLE;
        elsif rising_edge(clk) then
            pat_sta <= pat_nxt;
        end if;
    end process;

    -- Автомат последовательно выводит красный, зелёный и синий кадры.
    process(all)
    begin
        pat_nxt <= pat_sta;

        case pat_sta is
            when PAT_IDLE =>
                if pat_enb = '1' then
                    pat_nxt <= PAT_R_PAT_S;
                end if;

            when PAT_R_PAT_S =>
                if update_start = '1' then
                    pat_nxt <= PAT_R_PAT;
                end if;

            when PAT_R_PAT =>
                pat_nxt <= PAT_R_PAT_F;

            when PAT_R_PAT_F =>
                if frame_end = '1' then
                    pat_nxt <= PAT_G_PAT_S;
                elsif write_enb = '1' and write_enb_ack = '1' then
                    pat_nxt <= PAT_R_PAT;
                end if;

            when PAT_G_PAT_S =>
                if update_start = '1' then
                    pat_nxt <= PAT_G_PAT;
                end if;

            when PAT_G_PAT =>
                pat_nxt <= PAT_G_PAT_F;

            when PAT_G_PAT_F =>
                if frame_end = '1' then
                    pat_nxt <= PAT_B_PAT_S;
                elsif write_enb = '1' and write_enb_ack = '1' then
                    pat_nxt <= PAT_G_PAT;
                end if;

            when PAT_B_PAT_S =>
                if update_start = '1' then
                    pat_nxt <= PAT_B_PAT;
                end if;

            when PAT_B_PAT =>
                pat_nxt <= PAT_B_PAT_F;

            when PAT_B_PAT_F =>
                if frame_end = '1' then
                    pat_nxt <= PAT_R_PAT_S;
                elsif write_enb = '1' and write_enb_ack = '1' then
                    pat_nxt <= PAT_B_PAT;
                end if;

            when others =>
                pat_nxt <= PAT_IDLE;
        end case;
    end process;

    -- Импульс запроса на начало полного обновления кадра.
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            frame_upd_start <= '0';
        elsif rising_edge(clk) then
            if update_start = '1' and
               (pat_sta = PAT_R_PAT_S or
                pat_sta = PAT_G_PAT_S or
                pat_sta = PAT_B_PAT_S) then
                frame_upd_start <= '1';
            else
                frame_upd_start <= '0';
            end if;
        end if;
    end process;

    -- Удерживаем разрешение записи до подтверждения или конца кадра.
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            write_enb <= '0';
        elsif rising_edge(clk) then
            if pat_sta = PAT_R_PAT or
               pat_sta = PAT_G_PAT or
               pat_sta = PAT_B_PAT then
                write_enb <= '1';
            elsif write_enb_ack = '1' or frame_end = '1' then
                write_enb <= '0';
            end if;
        end if;
    end process;

    -- Установка конкретных оттенков в зависимости от стейта
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            data_buff <= (others => '0');
        elsif rising_edge(clk) then
            case pat_sta is
                when PAT_R_PAT => data_buff <= x"001F";
                when PAT_G_PAT => data_buff <= x"07E0";
                when PAT_B_PAT => data_buff <= x"F800";
                when others    => null;
            end case;
        end if;
    end process;

end architecture rtl;
