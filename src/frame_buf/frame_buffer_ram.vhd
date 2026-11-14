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

        -- От дисплея (обратная связь)
        initial_done     : in  std_logic;
        frame_update     : in  std_logic;
        data_bvld_ack    : in  std_logic;

        -- К дисплею (потоковый интерфейс)
        frame_upd_start  : out std_logic;
        single_upd_start : out std_logic;
        x_coordinate     : out std_logic_vector(8 downto 0);
        y_coordinate     : out std_logic_vector(8 downto 0);
        data_buf_valid   : out std_logic;
        data_buff        : out std_logic_vector(15 downto 0);

        -- К памяти
        ram_we           : out std_logic;
        ram_waddr        : out std_logic_vector(16 downto 0);
        ram_wdata        : out std_logic_vector(15 downto 0);
        ram_raddr        : out std_logic_vector(16 downto 0);
        ram_rdata        : in  std_logic_vector(15 downto 0)
    );
end frame_buffer_ctrl;

architecture rtl of frame_buffer_ctrl is
    type state_t is (
        CLEAR,           -- очистка RAM калибровочным квадратом и чёрным фоном
        WAIT_INIT,       -- ожидание инициализации LCD
        CLEAR_WAIT_ACK,  -- ожидание окончания вывода первого кадра
        IDLE,            -- ожидание события мыши
        MOVE,            -- вычисление целевой точки (target_x, target_y)
        DRAW,            -- отправка текущего пикселя на дисплей
        WAIT_ACK,        -- ожидание подтверждения data_bvld_ack
        WAIT_FRAME       -- ожидание frame_update и сдвиг курсора
    );
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

    -- Счётчик чтения RAM для полного кадра
    signal rd_cnt        : integer range 0 to 76799 := 0;
    signal frame_reading : std_logic := '0';
begin
    nx <= x + dx;
    ny <= y - dy;  -- Y инвертирован: dy>0 => вверх по экрану

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state            <= CLEAR;
            clear_x          <= 0;
            clear_y          <= 0;
            x                <= 120;
            y                <= 160;
            target_x         <= 120;
            target_y         <= 160;
            dx               <= 0;
            dy               <= 0;
            rd_cnt           <= 0;
            frame_reading    <= '0';
            frame_upd_start  <= '0';
            single_upd_start <= '0';
            x_coordinate     <= (others => '0');
            y_coordinate     <= (others => '0');

        elsif rising_edge(clk) then
            -- Значения по умолчанию (импульсы)
            frame_upd_start  <= '0';
            single_upd_start <= '0';

            -- Счётчик чтения RAM для полного кадра.
            -- Display запрашивает 241 * 320 = 77120 пикселей (лишний 1
            -- «хвост» на строку). RAM содержит 240 * 320 = 76800.
            -- Насыщаем rd_cnt на 76799, чтобы отдавать последний пиксель
            -- и не дать display зависнуть.
            if data_bvld_ack = '1' and frame_reading = '1' then
                if rd_cnt < 76799 then
                    rd_cnt <= rd_cnt + 1;
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
                    if initial_done = '1' then
                        frame_upd_start <= '1';
                        rd_cnt          <= 0;
                        frame_reading   <= '1';
                        state           <= CLEAR_WAIT_ACK;
                    end if;

                when CLEAR_WAIT_ACK =>
                    if frame_update = '1' then
                        frame_reading <= '0';
                        state         <= IDLE;
                    end if;

                when IDLE =>
                    if mouse_tick = '1' and mouse_btnm(0) = '1' then
                        dx    <= to_integer(signed(mouse_xm));
                        dy    <= to_integer(signed(mouse_ym));
                        state <= MOVE;
                    end if;

                when MOVE =>
                    -- Фиксируем target один раз
                    if nx < 0 then
                        target_x <= 0;
                    elsif nx > 239 then
                        target_x <= 239;
                    else
                        target_x <= nx;
                    end if;

                    if ny < 0 then
                        target_y <= 0;
                    elsif ny > 319 then
                        target_y <= 319;
                    else
                        target_y <= ny;
                    end if;

                    state <= DRAW;

                when DRAW =>
                    -- Отправляем ТЕКУЩИЙ пиксель (x, y) на дисплей.
                    -- Одиночный импульс single_upd_start на 1 такт.
                    single_upd_start <= '1';
                    x_coordinate     <= std_logic_vector(to_unsigned(x, 9));
                    y_coordinate     <= std_logic_vector(to_unsigned(y, 9));
                    state            <= WAIT_ACK;

                when WAIT_ACK =>
                    if data_bvld_ack = '1' then
                        state <= WAIT_FRAME;
                    end if;

                when WAIT_FRAME =>
                    if frame_update = '1' then
                        if (x = target_x) and (y = target_y) then
                            -- Достигли цели -> курсор остановился
                            state <= IDLE;
                        else
                            -- Сдвигаемся на 1 пиксель к цели и рисуем дальше
                            if x < target_x then
                                x <= x + 1;
                            elsif x > target_x then
                                x <= x - 1;
                            end if;
                            if y < target_y then
                                y <= y + 1;
                            elsif y > target_y then
                                y <= y - 1;
                            end if;
                            state <= DRAW;
                        end if;
                    end if;

                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;

    -- ------------------------------------------------------------------
    -- Комбинационная логика записи в RAM
    -- ------------------------------------------------------------------
    process(state, clear_x, clear_y, x, y)
    begin
        ram_we <= '1';

        if state = CLEAR then
            ram_waddr <= std_logic_vector(to_unsigned(clear_y * 240 + clear_x, 17));
            if clear_x < 10 and clear_y < 10 then
                ram_wdata <= x"FFFF";  -- калибровочный квадрат 10x10
            else
                ram_wdata <= x"0000";  -- чёрный фон
            end if;

        elsif state = DRAW then
            ram_waddr <= std_logic_vector(to_unsigned(y * 240 + x, 17));
            ram_wdata <= x"FFFF";      -- белый пиксель

        else
            ram_we    <= '0';
            ram_waddr <= (others => '0');
            ram_wdata <= (others => '0');
        end if;
    end process;

    -- ------------------------------------------------------------------
    -- Комбинационная логика чтения RAM и выдачи данных в display
    -- ------------------------------------------------------------------
    process(state, frame_reading, ram_rdata)
    begin
        if frame_reading = '1' then
            -- Полный кадр: отдаём поток из RAM
            data_buff      <= ram_rdata;
            data_buf_valid <= '1';

        elsif state = DRAW or state = WAIT_ACK or state = WAIT_FRAME then
            -- Одиночный пиксель: белый цвет
            data_buff      <= x"FFFF";
            data_buf_valid <= '1';

        else
            data_buff      <= x"0000";
            data_buf_valid <= '0';
        end if;
    end process;

    ram_raddr <= std_logic_vector(to_unsigned(rd_cnt, 17));

end rtl;