library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cmd2lcd_tb is
end entity cmd2lcd_tb;

architecture sim of cmd2lcd_tb is

    -- Параметры тестирования
    constant CLOCK_FREQ : natural := 100e3;
    constant CLK_PERIOD : time := 1 sec / CLOCK_FREQ;

    signal clk_tb             : std_logic := '0';
    signal rst_n_tb           : std_logic := '0';

    -- Входные команды от display
    signal cmd_valid_tb       : std_logic := '0';
    signal cmd_tb             : std_logic_vector(7 downto 0) := x"00";
    signal cmd_cycle_tb       : std_logic_vector(15 downto 0) := x"0001";
    signal data_wr_valid_tb   : std_logic := '0';
    signal data_wr_tb         : std_logic_vector(15 downto 0) := x"0000";

    -- Подтверждения от cmd2lcd
    signal ack_wr_tb          : std_logic;
    signal cmd_finish_tb      : std_logic;
    signal wrphase_finish_tb  : std_logic;

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
    DUT : entity work.cmd2lcd
        port map (
            clk             => clk_tb,
            rst_n           => rst_n_tb,

            cmd_valid       => cmd_valid_tb,
            cmd             => cmd_tb,
            cmd_cycle       => cmd_cycle_tb,
            data_wr_valid   => data_wr_valid_tb,
            data_wr         => data_wr_tb,

            ack_wr          => ack_wr_tb,
            cmd_finish      => cmd_finish_tb,
            wrphase_finish  => wrphase_finish_tb,

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
        -- variable sc_addr : unsigned(15 downto 0) := to_unsigned(239, 16);
        -- variable sp_addr : unsigned(15 downto 0) := to_unsigned(9, 16);
    begin

        -- 1. Сброс
        rst_n_tb <= '0';
        wait for 5 * CLK_PERIOD;

        wait until rising_edge(clk_tb);
        rst_n_tb <= '1';

        -- Установка диапазона X: 0..239
        cmd_tb       <= x"2A"; -- CASET
        cmd_cycle_tb <= std_logic_vector(to_unsigned(2, 16));
        cmd_valid_tb <= '1';

        wait until rising_edge(clk_tb);
        cmd_valid_tb <= '0';

        -- Начальная координата X = 0
        data_wr_tb       <= x"0000";
        data_wr_valid_tb <= '1';

        wait until ack_wr_tb = '1';
        wait until ack_wr_tb = '0';

        -- Конечная координата X = 239
        data_wr_tb <= x"00EF";

        wait until ack_wr_tb = '1';
        data_wr_valid_tb <= '0';
        wait until cmd_finish_tb = '1';
        wait until rising_edge(clk_tb);

        -- Установка диапазона Y: 0..9
        cmd_tb       <= x"2B"; -- PASET
        cmd_cycle_tb <= std_logic_vector(to_unsigned(2, 16));
        cmd_valid_tb <= '1';

        wait until rising_edge(clk_tb);
        cmd_valid_tb <= '0';

        -- Начальная координата Y = 0
        data_wr_tb       <= x"0000";
        data_wr_valid_tb <= '1';

        wait until ack_wr_tb = '1';
        wait until ack_wr_tb = '0';

        -- Конечная координата Y = 9
        data_wr_tb <= x"0009";

        wait until ack_wr_tb = '1';
        data_wr_valid_tb <= '0';
        wait until cmd_finish_tb = '1';
        wait until rising_edge(clk_tb);

        -- Начало записи пикселей
        cmd_tb       <= x"2C"; -- RAMWR
        cmd_cycle_tb <= std_logic_vector(to_unsigned(2400, 16));
        cmd_valid_tb <= '1';

        wait until rising_edge(clk_tb);
        cmd_valid_tb <= '0';

        -- Заполнение первых 10 строк красным
        for i in 0 to 2399 loop
            data_wr_tb       <= x"F800";
            data_wr_valid_tb <= '1';

            wait until ack_wr_tb = '1';
            wait until ack_wr_tb = '0';
        end loop;

        data_wr_valid_tb <= '0';
        -- -- Установка диапазона X: 0..239
        -- cmd_tb       <= x"2A"; -- CASET
        -- cmd_cycle_tb <= std_logic_vector(to_unsigned(4,16));
        -- cmd_valid_tb <= '1';
        -- wait until rising_edge(clk_tb);
        -- cmd_valid_tb <= '0';

        -- -- Начальная и конечная координаты X
        -- data_wr_valid_tb <= '1';
        -- data_wr_tb       <= x"00" & std_logic_vector(to_unsigned(0,8));
        -- wait until rising_edge(clk_tb);
        -- data_wr_tb       <= x"00" & std_logic_vector(to_unsigned(0,8));
        -- wait until rising_edge(clk_tb);
        -- data_wr_tb       <= x"00" & std_logic_vector(sc_addr(15 downto 8));
        -- wait until rising_edge(clk_tb);
        -- data_wr_tb       <= x"00" & std_logic_vector(sc_addr(7 downto 0));
        -- wait until rising_edge(clk_tb);
        -- data_wr_valid_tb <= '0';

        -- wait until ack_wr_tb = '1';
        -- wait until rising_edge(clk_tb);

        -- -- Установка диапазона Y: 0..10
        -- cmd_tb       <= x"2B"; -- PASET
        -- cmd_cycle_tb <= std_logic_vector(to_unsigned(2,16));
        -- cmd_valid_tb <= '1';
        -- wait until rising_edge(clk_tb);
        -- cmd_valid_tb <= '0';

        -- -- Начальная и конечная координаты Y
        -- data_wr_tb       <= std_logic_vector(to_unsigned(0,16));
        -- data_wr_valid_tb <= '1';
        -- wait until rising_edge(clk_tb);
        -- wait until ack_wr_tb = '1';
        -- data_wr_tb <= std_logic_vector(to_unsigned(9,16));
        -- wait until rising_edge(clk_tb);
        -- wait until ack_wr_tb = '1';
        -- data_wr_valid_tb <= '0';

        -- -- Начало записи пикселей
        -- cmd_tb       <= x"2C"; -- RAMWR
        -- cmd_cycle_tb <= std_logic_vector(to_unsigned(240 * 10, 16));
        -- cmd_valid_tb <= '1';
        -- wait until rising_edge(clk_tb);
        -- cmd_valid_tb <= '0';

        -- -- Заполнение красным первых 10ти строк
        -- for i in 0 to (240 * 10 - 1) loop
        --     data_wr_tb       <= x"F800";
        --     data_wr_valid_tb <= '1';

        --     wait until rising_edge(clk_tb);
        --     wait until ack_wr_tb = '1';
        -- end loop;

        -- data_wr_valid_tb <= '0';

        -- Наблюдаем завершение обмена
        wait for 100 * CLK_PERIOD;

        wait;
    end process;

end architecture sim;