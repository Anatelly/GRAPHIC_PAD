--таймер на 33мс. Выдает однократный флаг при срабатывании
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timer is
    generic (
        -- Количество тактов для периода 33 мс
        COUNT_33MS_END : integer range 0 to 2000000 := 16#192D50#
    );
    port (
        clk          : in  std_logic;
        rst_n        : in  std_logic;
        trigger_33ms : out std_logic
    );
end entity timer;

architecture rtl of timer is
    -- Счётчик тактов сигнала
    signal count_33ms : unsigned(20 downto 0) := (others => '0');

begin

    -- Счётчик работает от тактового сигнала
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            count_33ms <= (others => '0');

        elsif rising_edge(clk) then
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
            trigger_33ms <= '0';

        elsif rising_edge(clk) then
            if count_33ms = to_unsigned(COUNT_33MS_END, count_33ms'length) then
                trigger_33ms <= '1';
            else
                trigger_33ms <= '0';
            end if;
        end if;
    end process;

end architecture rtl;
