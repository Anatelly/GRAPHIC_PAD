library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd_lt24_tb is
end entity lcd_lt24_tb;

architecture tb of lcd_lt24_tb is

    -- Параметры тестирования
    constant CLK_PERIOD : time := 20 ns; --50МГц

    -- Generic-параметры DUT
    constant W_HIGH_END_TB : natural := 2;
    constant W_LOW_END_TB  : natural := 2;

    -- Входные сигналы DUT
    signal clk_tb           : std_logic := '0';
    signal rst_n_tb         : std_logic := '0';

    signal cmd_valid_tb     : std_logic := '0';
    signal cmd_tb           : std_logic_vector(7 downto 0)
                             := (others => '0');
    signal cmd_cycle_tb     : std_logic_vector(15 downto 0)
                             := (others => '0');

    signal data_wr_valid_tb : std_logic := '0';
    signal data_wr_tb       : std_logic_vector(15 downto 0)
                             := (others => '0');

    -- Выходные сигналы DUT
    signal ack_wr_tb        : std_logic;
    signal cmd_finish_tb    : std_logic;
    signal wrphase_finish_tb : std_logic;

    signal csn_tb           : std_logic;
    signal data_cmdn_tb     : std_logic;
    signal wrn_tb           : std_logic;
    signal rdn_tb           : std_logic;

    -- Двунаправленная шина LCD
    signal data_lcd_tb      : std_logic_vector(15 downto 0);

begin

    -- =====================================================
    -- Генератор тактового сигнала
    -- =====================================================
    clk_tb <= not clk_tb after CLK_PERIOD / 2;


    -- =====================================================
    -- Подключение тестируемого модуля (DUT)
    -- =====================================================
    DUT : entity work.lcd_lt24
        generic map (
            W_HIGH_END => W_HIGH_END_TB,
            W_LOW_END  => W_LOW_END_TB
        )
        port map (
            clk            => clk_tb,
            rst_n          => rst_n_tb,

            cmd_valid      => cmd_valid_tb,
            cmd            => cmd_tb,
            cmd_cycle      => cmd_cycle_tb,

            data_wr_valid  => data_wr_valid_tb,
            data_wr        => data_wr_tb,

            ack_wr         => ack_wr_tb,
            cmd_finish     => cmd_finish_tb,
            wrphase_finish => wrphase_finish_tb,

            csn            => csn_tb,
            data_cmdn      => data_cmdn_tb,
            wrn            => wrn_tb,
            rdn            => rdn_tb,

            data_lcd       => data_lcd_tb
        );


    -- =====================================================
    -- Тестовый процесс
    -- Здесь напиши свой сценарий проверки
    -- =====================================================
    SIM_PROC : process
    begin

        -- TODO: Сброс DUT

        -- TODO: Подготовка входных данных

        -- TODO: Передача команды

        -- TODO: Передача слова/слов данных

        -- TODO: Проверка выходных сигналов

        -- TODO: Завершение симуляции
        wait;
    end process SIM_PROC;


end architecture tb;
