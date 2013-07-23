hold off;
t=-4:0.5:0;
a=-0.4;
b=-1.5;
c=-3;
u=exp(t);

d=0.01+exp(c) + exp(c)*t - exp(c)*c;  # using the value at c
e=0.02+exp(b) + exp(b)*t - exp(b)*b;  # using the value at b
f=0.04+exp(a) + exp(a)*t - exp(a)*a;  # Using the value at a
g=(1/4)*t+1; # strict linear approx

cc=hsv(12);
clf
hold on
ylim([0 1])
xlim([-4 0])
plot(t,u,'color',[1 0 0])
plot(t,d,'color',[0 0 1])
plot(t,e)
plot(t,f)
