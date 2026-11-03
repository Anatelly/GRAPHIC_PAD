library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd_top_tb is
end entity lcd_top_tb;

architecture tb of lcd_top_tb is

    -- Параметры тестирования
    constant CLOCK_FREQ : natural := 50e6;
    constant CLK_PERIOD : time := 1 sec / CLOCK_FREQ;

    -- Тактирование и сброс
    signal clk_tb : std_logic := '0';
    signal rst_n_tb : std_logic := '0';

    -- Интерфейс LCD
    signal csn_tb      : std_logic;
    signal data_cmdn_tb : std_logic;
    signal wrn_tb      : std_logic;
    signal rdn_tb      : std_logic;
    signal data_lcd_tb : std_logic_vector(15 downto 0);
    signal lcd_on_tb      : std_logic;
    signal lcd_reset_tb   : std_logic;

begin

    ----------------------------------------------------------------
    -- Генератор тактового сигнала
    ----------------------------------------------------------------
    clk_tb <= not clk_tb after CLK_PERIOD / 2;

    ----------------------------------------------------------------
    -- Модуль управления
    ----------------------------------------------------------------
    DUT : entity work.lcd_top
        port map (
            clk       => clk_tb,
            rst_n     => rst_n_tb,

            csn       => csn_tb,
            data_cmdn => data_cmdn_tb,
            wrn       => wrn_tb,
            rdn       => rdn_tb,
            data_lcd  => data_lcd_tb,
            lcd_on    => lcd_on_tb,
            lcd_reset => lcd_reset_tb
        );

    ----------------------------------------------------------------
    -- Основной сценарий тестирования
    ----------------------------------------------------------------
    PROC : process
    begin
        -- Сброс модулей
        rst_n_tb <= '0';
        wait for CLK_PERIOD;
        wait until falling_edge(clk_tb);
        rst_n_tb <= '1';
        report "TB: reset released" severity note;

        wait;
    end process;

end architecture tb;
