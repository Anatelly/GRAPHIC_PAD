library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_buffer_ram is
    port (
        clk:in std_logic;
        wr_en:in std_logic;
        wr_addr:in std_logic_vector(16 downto 0);
        wr_data:in std_logic_vector(15 downto 0);
        rd_addr:in std_logic_vector(16 downto 0);
        rd_data:out std_logic_vector(15 downto 0)
    );
end entity;

architecture rtl of frame_buffer_ram is
    type ram_type is array (0 to 131071) of std_logic_vector(15 downto 0);
    signal ram : ram_type;
    signal rd_data_reg:std_logic_vector(15 downto 0);
begin
    process(clk)
    begin
        if rising_edge(clk) then

            if wr_en = '1' then
                ram(to_integer(unsigned(wr_addr))) <= wr_data;
            end if;
                rd_data_reg <= ram(to_integer(unsigned(rd_addr)));
        end if;
    end process;

    rd_data <= rd_data_reg;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_buffer_ctrl is
    port (
        clk:in std_logic;
        reset:in std_logic;
		  
        xm:in std_logic_vector(8 downto 0);
        ym:in std_logic_vector(8 downto 0);
        btnm:in std_logic_vector(2 downto 0);
		  
        m_done_tick:in std_logic;
        brush_color:in std_logic_vector(15 downto 0) := x"FFFF";
        
        wr_en:out std_logic;
        wr_addr:out std_logic_vector(16 downto 0);
        wr_data:out std_logic_vector(15 downto 0)
    );
end entity;

architecture rtl of frame_buffer_ctrl is
    signal x_pos:integer:= 120;
    signal y_pos:integer:= 160;
    
    signal clear_cnt:integer;
    signal clearing:std_logic;
begin
    process(clk, reset)
        variable new_x:integer;
        variable new_y:integer;
    begin
        
        if reset = '1' then 
            x_pos<=120;
            y_pos<=160;
            clear_cnt<=0;
            clearing<= '1';
            wr_en<='0';
            
        elsif rising_edge(clk) then
            if clearing='1' then--очистка экрана
                wr_en<='1';
                wr_addr<=std_logic_vector(to_unsigned(clear_cnt, 17));
                wr_data<=x"0000";--цвет
                
                if clear_cnt=76799 then
                    clearing<='0';--очистка завершена
                else
                    clear_cnt <= clear_cnt + 1;
                end if;
                
            
            else--работа
                wr_en <= '0';
                
                if m_done_tick = '1' then
                    --новые координаты
                    new_x := x_pos + to_integer(signed(xm));
                    new_y := y_pos + to_integer(signed(ym));
                    --ограничие по краям
                    if new_x<0 then 
						      new_x:=0;
						  end if;
						  
                    if new_x>239 then
						      new_x:=239;
						  end if;
						  
                    if new_y<0 then
						      new_y:=0;
						  end if;
                    if new_y>319 then
						      new_y:=319; 
						  end if;

                    x_pos <= new_x;
                    y_pos <= new_y;
                    
                    if btnm(0) = '1' then
                        wr_en   <= '1';
                        wr_addr <= std_logic_vector(to_unsigned(new_y * 240 + new_x, 17));
                        wr_data <= brush_color;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_buffer is
    port (
        clk:in std_logic;
        reset:in  std_logic;
        xm:in std_logic_vector(8 downto 0);
        ym:in std_logic_vector(8 downto 0);
        btnm:in std_logic_vector(2 downto 0);
		  
        m_done_tick:in std_logic;
        brush_color:in std_logic_vector(15 downto 0);
        
        rd_addr:in std_logic_vector(16 downto 0);
        rd_data:out std_logic_vector(15 downto 0)
    );
end entity;

architecture rtl of frame_buffer is
    signal wire_wr_en:std_logic;
    signal wire_wr_addr:std_logic_vector(16 downto 0);
    signal wire_wr_data:std_logic_vector(15 downto 0);
begin
    ctrl_unit: entity work.frame_buffer_ctrl
        port map (
            clk => clk,
            reset => reset,
            xm => xm,
            ym => ym,
            btnm => btnm,
            m_done_tick => m_done_tick,
            brush_color => brush_color,
            wr_en => wire_wr_en,
            wr_addr => wire_wr_addr,
            wr_data => wire_wr_data
        );

    ram_unit: entity work.frame_buffer_ram
        port map (
            clk => clk,
            wr_en => wire_wr_en,
            wr_addr => wire_wr_addr,
            wr_data => wire_wr_data,
            rd_addr => rd_addr,
            rd_data => rd_data
        );
end architecture;