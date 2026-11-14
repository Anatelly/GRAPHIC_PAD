library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_buffer_ram is
    port (
        clk   : in  std_logic;
        we    : in  std_logic;
        waddr : in  std_logic_vector(16 downto 0);
        wdata : in  std_logic_vector(15 downto 0);
        raddr : in  std_logic_vector(16 downto 0);
        rdata : out std_logic_vector(15 downto 0)
    );
end frame_buffer_ram;

architecture rtl of frame_buffer_ram is
    type ram_type is array (0 to 76799) of std_logic_vector(15 downto 0);
    signal ram : ram_type := (others => x"0000");

    attribute ramstyle : string;
    attribute ramstyle of ram : signal is "M9K";
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                ram(to_integer(unsigned(waddr))) <= wdata;
            end if;
            rdata <= ram(to_integer(unsigned(raddr)));
        end if;
    end process;
end rtl;