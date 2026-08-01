namespace AllyClicker.Core.Tests;

public class PointTests
{
    [Fact]
    public void Zero_IsTheOrigin()
    {
        Assert.Equal(0, Point.Zero.X);
        Assert.Equal(0, Point.Zero.Y);
    }

    [Fact]
    public void DistanceTo_IsEuclidean()
    {
        var a = new Point(0, 0);
        var b = new Point(3, 4);

        Assert.Equal(5, a.DistanceTo(b), precision: 10);
        Assert.Equal(5, b.DistanceTo(a), precision: 10);
    }

    [Fact]
    public void DistanceTo_Self_IsZero()
    {
        var p = new Point(-17.5, 42.25);

        Assert.Equal(0, p.DistanceTo(p));
    }

    [Fact]
    public void Equality_IsByValue()
    {
        Assert.Equal(new Point(1.5, -2.5), new Point(1.5, -2.5));
        Assert.NotEqual(new Point(1.5, -2.5), new Point(1.5, 2.5));
    }
}
