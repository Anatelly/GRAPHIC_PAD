library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cmdlcd_read_tb is
end entity cmdlcd_read_tb;

architecture tb of cmdlcd_read_tb is

    -- Параметры тестирования
    constant CLOCK_FREQ : natural := 100e3;
    constant CLK_PERIOD : time := 1 sec / CLOCK_FREQ;

    signal clk_tb             : std_logic := '0';
    signal rst_n_tb           : std_logic := '0';

    -- Входные команды от display
    signal ledr_tb            : std_logic_vector(15 downto 0);
    signal test_done_tb       : std_logic := '0';

    -- Физический интерфейс LCD
    signal csn_tb             : std_logic;
    signal data_cmdn_tb       : std_logic;
    signal wrn_tb             : std_logic;
    signal rdn_tb             : std_logic;
    signal data_lcd_tb        : std_logic_vector(15 downto 0);

begin

    --------------------------------------------------------------------
    -- Тактовый сигнал
    --------------------------------------------------------------------
    clk_tb <= not clk_tb after CLK_PERIOD / 2;

    --------------------------------------------------------------------
    -- DUT: проверяемый модуль cmd2lcd
    --------------------------------------------------------------------
    DUT : entity work.cmdlcd_read
        port map (
            clk             => clk_tb,
            rst_n           => rst_n_tb,

            ledr            => ledr_tb,
            test_done       => test_done_tb,

            csn             => csn_tb,
            data_cmdn       => data_cmdn_tb,
            wrn             => wrn_tb,
            rdn             => rdn_tb,
            data_lcd        => data_lcd_tb
        );

    --------------------------------------------------------------------
    -- Тестовые воздействия
    --------------------------------------------------------------------
    SIM_PROC : process
    begin

        -- 1. Сброс
        rst_n_tb <= '0';
        wait until rising_edge(clk_tb);
        rst_n_tb <= '1';

        wait;
    end process;

end architecture tb;