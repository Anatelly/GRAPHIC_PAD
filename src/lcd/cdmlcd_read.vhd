library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cmdlcd_read is
    port (
        clk       : in    std_logic;
        rst_n     : in    std_logic;

        -- ----------------------------------------------------
        -- Управляющие сигналы LCD
        -- ----------------------------------------------------
        csn : out std_logic;
        -- Chip Select, активный низким уровнем.
        -- '0' — LCD выбран для обмена данными.

        data_cmdn : out std_logic;
        -- Выбор типа передаваемой информации.
        -- '0' — передается команда;
        -- '1' — передаются данные.
        -- Обычно соответствует сигналу D/C или RS дисплея.

        wrn : out std_logic;
        -- Write Strobe, активный низким уровнем.
        -- Низкий уровень обозначает активную фазу записи.

        rdn : out std_logic;
        -- Read Strobe, активный низким уровнем.
        -- Чтение из дисплея не используется, поэтому сигнал
        -- постоянно удерживается в неактивном состоянии ('1').

        -- ----------------------------------------------------
        -- Двунаправленная шина LCD
        -- ----------------------------------------------------
        data_lcd : inout std_logic_vector(15 downto 0);
        -- 16-битная шина данных дисплея.
        -- Во время записи модуль управляет шиной.
        -- В режиме отключенного выходного драйвера шина
        -- переводится в высокоимпедансное состояние 'Z'.
        lcd_on    : out std_logic;
        lcd_reset : out std_logic;

        -- ----------------------------------------------------
        -- Индикация результата
        -- ----------------------------------------------------
        ledr      : out   std_logic_vector(15 downto 0);
        test_done : out   std_logic
    );
end entity cmdlcd_read;

architecture rtl of cmdlcd_read is

    type state_t is (
        IDLE,
        CMD_SETUP,
        CMD_LOW,
        CMD_HIGH,
        CMD_END,

        READ_SETUP,
        READ_LOW,
        READ_SAMPLE,
        READ_HIGH,
        READ_NEXT,

        DONE
    );

    signal state : state_t := IDLE;

    signal db_out : std_logic_vector(15 downto 0);
    signal db_oe  : std_logic := '0';

    signal delay_cnt : integer range 0 to 4 := 0;
    signal read_cnt  : integer range 0 to 3 := 0;

    signal id_data : std_logic_vector(31 downto 0) :=
                     (others => '0');

begin

    lcd_on <= '1';
    -- FPGA drives bus only during command transmission
    data_lcd <= db_out when db_oe = '1' else (others => 'Z');

    -- Display DB[7:0] -> FPGA
    ledr <= id_data(23 downto 8);

    process(clk)
    begin
        if rising_edge(clk) then

            if rst_n = '0' then

                lcd_reset <= '0';
                state     <= IDLE;
                csn   <= '1';
                data_cmdn   <= '1';
                wrn   <= '1';
                rdn   <= '1';

                db_oe     <= '0';
                db_out    <= (others => '0');

                delay_cnt <= 0;
                read_cnt  <= 0;
                id_data   <= (others => '0');
                test_done <= '0';

            else
                lcd_reset <= '1';
                case state is

                    -- Start
                    when IDLE =>
                        csn <= '0';
                        data_cmdn <= '0';
                        wrn <= '1';
                        rdn <= '1';

                        db_oe  <= '1';
                        db_out <= x"0004"; -- RDDID

                        state <= CMD_SETUP;

                    -- Command write
                    when CMD_SETUP =>
                        wrn <= '0';
                        state <= CMD_LOW;

                    when CMD_LOW =>
                        wrn <= '1';
                        state <= CMD_HIGH;

                    when CMD_HIGH =>
                        state <= CMD_END;

                    when CMD_END =>
                        db_oe <= '0';
                        data_cmdn <= '1';
                        delay_cnt <= 0;
                        state <= READ_SETUP;

                    -- Read first byte (dummy)
                    when READ_SETUP =>
                        rdn <= '0';
                        delay_cnt <= 0;
                        state <= READ_LOW;

                    when READ_LOW =>
                        if delay_cnt = 2 then
                            state <= READ_SAMPLE;
                        else
                            delay_cnt <= delay_cnt + 1;
                        end if;

                    -- Capture DB[7:0]
                    when READ_SAMPLE =>
                        id_data(31 downto 24) <= data_lcd(7 downto 0);
                        rdn <= '1';
                        state <= READ_HIGH;

                    when READ_HIGH =>
                        if delay_cnt = 4 then
                            read_cnt <= 0;
                            state <= READ_NEXT;
                        else
                            delay_cnt <= delay_cnt + 1;
                        end if;

                    -- Read ID1, ID2, ID3
                    when READ_NEXT =>

                        if read_cnt = 3 then
                            csn <= '1';
                            state <= DONE;

                        else
                            rdn <= '0';
                            delay_cnt <= 0;

                            state <= READ_SAMPLE;
                        end if;

                    when DONE =>
                        test_done <= '1';

                end case;

            end if;
        end if;
    end process;

end architecture;