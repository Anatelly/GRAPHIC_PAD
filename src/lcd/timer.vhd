--таймер на 33мс. Выдает однократный флаг при срабатывании
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timer is
    generic (
        -- Количество тактов для периода 33 мс
        COUNT_33MS_END : integer range 0 to 65535 := 16#0CE4#
    );
    port (
        clk          : in  std_logic;
        rst_n        : in  std_logic;
        trigger_33ms : out std_logic
    );
end entity timer;

architecture rtl of timer is

    -- Сигналы PLL: тактирование 100 кГц и признак готовности
    signal clk_100khz    : std_logic;
    signal clk100khz_lock : std_logic;

    -- Сигналы формирования импульса
    signal cycle_33ms     : std_logic := '0';
    signal cycle_33ms_dly : std_logic := '0';

    -- Счётчик тактов сигнала 100 кГц
    signal count_33ms : unsigned(15 downto 0) := (others => '0');

    -- Интерфейс PLL, созданного в Quartus
    component pll_50M_to_100K is
        port (
            areset : in  std_logic;
            inclk0 : in  std_logic;
            c0     : out std_logic;
            locked : out std_logic
        );
    end component;

begin

    -- PLL преобразует входные 50 МГц в 100 кГц
    pll_inst : pll_50M_to_100K
        port map (
            areset => not rst_n,
            inclk0 => clk,
            c0     => clk_100khz,
            locked => clk100khz_lock
        );

    -- Счётчик работает от тактового сигнала 100 кГц
    process(clk_100khz, clk100khz_lock)
    begin
        if clk100khz_lock = '0' then
            count_33ms <= (others => '0');

        elsif rising_edge(clk_100khz) then
            if count_33ms = to_unsigned(COUNT_33MS_END, count_33ms'length) then
                count_33ms <= (others => '0');
            else
                count_33ms <= count_33ms + 1;
            end if;
        end if;
    end process;

    -- Формирование сигнала окончания периода
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            cycle_33ms <= '0';

        elsif rising_edge(clk) then
            if count_33ms = to_unsigned(COUNT_33MS_END, count_33ms'length) then
                cycle_33ms <= '1';
            else
                cycle_33ms <= '0';
            end if;
        end if;
    end process;

    -- Задержка сигнала на один такт clk
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            cycle_33ms_dly <= '0';

        elsif rising_edge(clk) then
            cycle_33ms_dly <= cycle_33ms;
        end if;
    end process;

    -- Выдача импульса при появлении фронта cycle_33ms
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            trigger_33ms <= '0';

        elsif rising_edge(clk) then
            if cycle_33ms = '1' and cycle_33ms_dly = '0' then
                trigger_33ms <= '1';
            else
                trigger_33ms <= '0';
            end if;
        end if;
    end process;

end architecture rtl;
