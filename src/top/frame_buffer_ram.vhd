library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_buffer_ctrl is
    port (
        clk              : in  std_logic;
        rst_n            : in  std_logic;

        -- От мыши
        mouse_xm         : in  std_logic_vector(8 downto 0);
        mouse_ym         : in  std_logic_vector(8 downto 0);
        mouse_btnm       : in  std_logic_vector(2 downto 0);
        mouse_tick       : in  std_logic;

        -- От дисплея (как в rgb_test_simple)
        initial_done     : in  std_logic;
        frame_update     : in  std_logic;
        data_bvld_ack    : in  std_logic;

        -- К дисплею (как в rgb_test_simple)
        frame_upd_start  : out std_logic;
        single_upd_start : out std_logic;
        x_coordinate     : out std_logic_vector(8 downto 0);
        y_coordinate     : out std_logic_vector(8 downto 0);
        data_buf_valid   : out std_logic;
        data_buff        : out std_logic_vector(15 downto 0);

        -- К памяти (RAM)
        ram_we           : out std_logic;
        ram_waddr        : out std_logic_vector(16 downto 0);
        ram_wdata        : out std_logic_vector(15 downto 0);
        ram_raddr        : out std_logic_vector(16 downto 0);
        ram_rdata        : in  std_logic_vector(15 downto 0)
    );
end frame_buffer_ctrl;

architecture rtl of frame_buffer_ctrl is
    -- Сохранили твои 4 состояния и добавили служебные для дисплея
    type state_t is (CLEAR, WAIT_INIT, CLEAR_WAIT_ACK, IDLE, MOVE, DRAW, WAIT_ACK, WAIT_FRAME);
    signal state : state_t := CLEAR;

    signal x        : integer range 0 to 239 := 120;
    signal y        : integer range 0 to 319 := 160;
    
    signal dx       : integer range -256 to 255 := 0;
    signal dy       : integer range -256 to 255 := 0;
    
    signal nx       : integer range -1024 to 1023;
    signal ny       : integer range -1024 to 1023;

    signal target_x : integer range 0 to 239 := 120;
    signal target_y : integer range 0 to 319 := 160;

    signal clear_x  : integer range 0 to 239 := 0;
    signal clear_y  : integer range 0 to 319 := 0;

    -- Счетчик чтения для полного кадра
    signal rd_cnt        : integer range 0 to 76799 := 0;
    signal frame_reading : std_logic := '0';

begin
    nx <= x + dx;
    ny <= y - dy; -- Сохранил твою инверсию Y, если курсор ездит вверх ногами, поменяй на "y + dy"

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= CLEAR;
            clear_x <= 0;
            clear_y <= 0;
            x <= 120;
            y <= 160;
            target_x <= 120;
            target_y <= 160;
            dx <= 0;
            dy <= 0;
            rd_cnt <= 0;
            frame_reading <= '0';
            frame_upd_start <= '0';
            single_upd_start <= '0';
            x_coordinate <= (others => '0');
            y_coordinate <= (others => '0');

        elsif rising_edge(clk) then
            frame_upd_start <= '0';
            single_upd_start <= '0';

            -- Логика инкремента адреса чтения при обновлении кадра
            if data_bvld_ack = '1' and frame_reading = '1' then
                if rd_cnt < 76799 then
                    rd_cnt <= rd_cnt + 1;
                else
                    frame_reading <= '0';
                end if;
            end if;

            case state is
                when CLEAR =>
                    if clear_x = 239 and clear_y = 319 then
                        state   <= WAIT_INIT;
                        clear_x <= 0;
                        clear_y <= 0;
                    elsif clear_x = 239 then
                        clear_x <= 0;
                        clear_y <= clear_y + 1;
                    else
                        clear_x <= clear_x + 1;
                    end if;

                when WAIT_INIT =>
                    -- Ждем инициализацию дисплея
                    if initial_done = '1' then
                        frame_upd_start <= '1';
                        rd_cnt <= 0;
                        frame_reading <= '1';
                        state <= CLEAR_WAIT_ACK;
                    end if;

                when CLEAR_WAIT_ACK =>
                    -- Ждем, пока дисплей отрисует первый кадр
                    if frame_update = '1' then
                        state <= IDLE;
                    end if;

                when IDLE =>
                    if mouse_tick = '1' and mouse_btnm(0) = '1' then
                        dx    <= to_integer(signed(mouse_xm));
                        dy    <= to_integer(signed(mouse_ym));
                        state <= MOVE;
                    end if;

                when MOVE =>
                    if nx < 0 then target_x <= 0;
                    elsif nx > 239 then target_x <= 239;
                    else target_x <= nx;
                    end if;

                    if ny < 0 then target_y <= 0;
                    elsif ny > 319 then target_y <= 319;
                    else target_y <= ny;
                    end if;

                    state <= DRAW;

                when DRAW =>
                    if (x = target_x) and (y = target_y) then
                        state <= IDLE;
                    else
                        if x < target_x then x <= x + 1;
                        elsif x > target_x then x <= x - 1;
                        end if;

                        if y < target_y then y <= y + 1;
                        elsif y > target_y then y <= y - 1;
                        end if;

                        single_upd_start <= '1';
                        x_coordinate <= std_logic_vector(to_unsigned(x, 9));
                        y_coordinate <= std_logic_vector(to_unsigned(y, 9));

                        state <= WAIT_ACK;
                    end if;

                when WAIT_ACK =>
                    -- Ждем подтверждения приема пикселя от display
                    if data_bvld_ack = '1' then
                        state <= WAIT_FRAME;
                    end if;

                when WAIT_FRAME =>
                    -- Ждем завершения обновления пикселя на экране
                    if frame_update = '1' then
                        state <= MOVE;
                    end if;

                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;

    -- Комбинационная логика записи в RAM (сохранена твоя логика)
    process(state, clear_x, clear_y, x, y)
    begin
        ram_we <= '1';

        if state = CLEAR then
            ram_waddr <= std_logic_vector(to_unsigned(clear_y * 240 + clear_x, 17));
            if clear_x < 10 and clear_y < 10 then
                ram_wdata <= x"FFFF";     -- калибровочный квадрат
            else
                ram_wdata <= x"0000";     -- чёрный фон
            end if;

        elsif state = DRAW then
            ram_waddr <= std_logic_vector(to_unsigned(y * 240 + x, 17));
            ram_wdata <= x"FFFF";         -- белый пиксель

        else
            ram_we    <= '0';
            ram_waddr <= (others => '0');
            ram_wdata <= (others => '0');
        end if;
    end process;
    
    -- Комбинационная логика чтения из RAM и выдачи данных в display
    process(state, frame_reading, ram_rdata)
    begin
        if frame_reading = '1' then
            data_buff <= ram_rdata;
            data_buf_valid <= '1';
        elsif state = DRAW or state = WAIT_ACK then
            data_buff <= x"FFFF";
            data_buf_valid <= '1';
        else
            data_buff <= x"0000";
            data_buf_valid <= '0';
        end if;
    end process;

    ram_raddr <= std_logic_vector(to_unsigned(rd_cnt, 17));

end rtl;