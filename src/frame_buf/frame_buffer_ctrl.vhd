library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_buffer_ctrl is
    port (
        clk:in std_logic;
        rst_n:in std_logic;
        -- От мыши
        mouse_xm:in std_logic_vector(8 downto 0);
        mouse_ym:in std_logic_vector(8 downto 0);
        mouse_btnm:in std_logic_vector(2 downto 0);
        mouse_tick:in std_logic;
        -- От монитора (запрос на чтение)
        rd_addr:in std_logic_vector(16 downto 0);
        -- К памяти
        ram_we:out std_logic;
        ram_waddr:out std_logic_vector(16 downto 0);
        ram_wdata:out std_logic_vector(15 downto 0);
        ram_raddr:out std_logic_vector(16 downto 0);
        -- Запрос на обновление экрана
        frame_req: out std_logic
    );
end frame_buffer_ctrl;

architecture rtl of frame_buffer_ctrl is
    type state_t is (CLEAR, IDLE, MOVE, DRAW);
    signal state : state_t;

    signal x:integer range 0 to 239 := 120;
    signal y:integer range 0 to 319 := 160;
    
    signal dx:integer range -256 to 255 := 0;
    signal dy:integer range -256 to 255 := 0;
    
    signal nx:integer range -1024 to 1023;
    signal ny:integer range -1024 to 1023;

    signal target_x: integer range 0 to 239;
    signal target_y: integer range 0 to 319;

    signal clear_x:integer range 0 to 239 := 0;
    signal clear_y:integer range 0 to 319 := 0;

    signal frame_req_r : std_logic := '0';
begin
    nx <= x + dx;
    ny <= y - dy;

    frame_req <= frame_req_r;

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state   <= CLEAR;
            clear_x <= 0;
            clear_y <= 0;
            x       <= 120;
            y       <= 160;
            target_x <= 120;
            target_y <= 160;
            dx      <= 0;
            dy      <= 0;
            frame_req_r <= '0';

        elsif rising_edge(clk) then
            frame_req_r <= '0'; -- По умолчанию 0

            case state is
                when CLEAR =>
                    if clear_x = 239 and clear_y = 319 then
                        state   <= IDLE;
                        clear_x <= 0;
                        clear_y <= 0;
                        frame_req_r <= '1'; -- Очистка завершена, обновляем экран
                    elsif clear_x = 239 then
                        clear_x <= 0;
                        clear_y <= clear_y + 1;
                    else
                        clear_x <= clear_x + 1;
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
                    if x < target_x then x <= x + 1;
                    elsif x > target_x then x <= x - 1;
                    end if;

                    if y < target_y then y <= y + 1;
                    elsif y > target_y then y <= y - 1;
                    end if;

                    if (x = target_x) and (y = target_y) then
                        state <= IDLE;
                        frame_req_r <= '1'; -- Линия нарисована, обновляем экран
                    end if;
            end case;
        end if;
    end process;

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
    
    ram_raddr <= rd_addr;
end rtl;