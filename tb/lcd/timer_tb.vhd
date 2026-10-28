library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timer_tb is
end entity timer_tb;

architecture tb of timer_tb is

    -- Параметры тестирования
    constant CLOCK_FREQ : natural := 100e3;
    constant CLK_PERIOD : time := 1 sec / CLOCK_FREQ;

    -- Порты
    signal clk_tb           : std_logic := '0';
    signal rst_n_tb         : std_logic := '1';
    signal trigger_33ms_tb  : std_logic := '0';
    

begin

    -- =====================================================
    -- Подключение тестируемого модуля (DUT)
    -- =====================================================
    DUT : entity work.timer
        port map (
            clk            => clk_tb,
            rst_n          => rst_n_tb,

            trigger_33ms      => trigger_33ms_tb
        );

    -- =====================================================
    -- Генератор тактового сигнала
    -- =====================================================
    clk_tb <= not clk_tb after CLK_PERIOD / 2;

    -- =====================================================
    -- Тестовый процесс
    -- Здесь напиши свой сценарий проверки
    -- =====================================================
    SIM_PROC : process
    begin

        wait for CLK_PERIOD*2;

        wait until rising_edge(clk_tb);

        rst_n_tb <= '0';

        wait until rising_edge(clk_tb);

        rst_n_tb <= '1';

        wait;
    end process SIM_PROC;


end architecture tb;
