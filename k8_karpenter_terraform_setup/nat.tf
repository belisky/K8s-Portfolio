resource "aws_eip" "nat_ip" {
    tags= {
        Name = "nat"
    }

}

resource "aws_nat_gateway" "nat_gw" {
    allocation_id = aws_eip.nat_ip.id
    subnet_id = aws_subnet.public_subnets.0.id

    tags = {
        Name="nat_gw"
    }

    depends_on=[aws_internal_gateway,igw]
}