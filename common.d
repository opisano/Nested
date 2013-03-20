module common;


interface IDisposable
{
    void dispose();
}

/**
* Checks value is in range [lower, upper[.
*/
bool between(uint value, uint lower, uint upper) pure nothrow
{
    return (lower <= value && upper > value);
}

bool among(T)(T value, T[] ts)
{
    foreach (t; ts)
    {
        if (t == value)
        {
            return true;
        }
    }
    return false;
}