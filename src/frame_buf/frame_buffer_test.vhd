library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_buffer_test is
    generic (
        -- Количество тактов для периода 33 мс
        COUNT_1MS_END : integer range 0 to 100000 := 16#11704#;
        COUNT_COORD_END   : integer range 0 to 200 := 120
    );
    port (
        clk              : in  std_logic;
        rst_n            : in  std_logic;

        mouse_xm         : out  std_logic_vector(8 downto 0);
        mouse_ym         : out  std_logic_vector(8 downto 0);
        mouse_btnm       : out  std_logic_vector(2 downto 0);
        mouse_tick       : out  std_logic

    );
end entity frame_buffer_test;


architecture rtl of frame_buffer_test is
    -- Счётчик тактов сигнала
    signal count_1ms : unsigned(20 downto 0) := (others => '0');
    signal count_coord : unsigned(7 downto 0) := (others => '0');
    signal trigger_1ms : std_logic;

begin

--=============TIMER===============================
    -- Счётчик работает от тактового сигнала
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            count_1ms <= (others => '0');

        elsif rising_edge(clk) then
            if count_1ms = to_unsigned(COUNT_1ms_END, count_1ms'length) then
                count_1ms <= (others => '0');
            else
                count_1ms <= count_1ms + 1;
            end if;
        end if;
    end process;

    -- Формирование сигнала окончания периода
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            trigger_1ms <= '0';

        elsif rising_edge(clk) then
            if count_1ms = to_unsigned(COUNT_1ms_END, count_1ms'length) then
                trigger_1ms <= '1';
            else
                trigger_1ms <= '0';
            end if;
        end if;
    end process;
--=============TIMER===============================

    -- начало рисования
    process(clk, trigger_1ms, rst_n)
    begin
        if rst_n = '0' then
            count_coord <= (others => '0');
            mouse_tick <= '0';
            mouse_btnm <= (others => '0');
            mouse_xm <= (others => '0');
            mouse_ym <= (others => '0');

        elsif rising_edge(trigger_1ms) then
            if count_coord < to_unsigned(COUNT_COORD_END, count_coord'length) then
                mouse_tick <= '1';
                mouse_xm <= std_logic_vector(unsigned(mouse_xm) + 1);
                mouse_ym <= '0' & x"A0";
                
                count_coord <= count_coord + to_unsigned(1, count_coord'length);
            else
                count_coord <= (others => '0');
                mouse_xm <= (others => '0');
                mouse_ym <= '0' & x"A0";
            end if;

        elsif falling_edge(trigger_1ms) then
            mouse_tick <= '0';
        end if;
    end process;



end architecture rtl;