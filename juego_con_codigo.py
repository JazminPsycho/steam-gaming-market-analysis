almacenamiento = 100

almacenamiento_consumido = 100

if almacenamiento_consumido < almacenamiento:
    print("Aún hay espacio disponible en el almacenamiento.")
    print("Te voy a crear una lista con elementos para que el almacenamiento se consuma.")
    lista = [10, 20, 30, 40]
    if almacenamiento_consumido == sum(lista):
        print("El almacenamiento se ha llenado completamente.")
    elif almacenamiento_consumido < sum(lista):
        print("El almacenamiento se ha llenado parcialmente.")
    elif almacenamiento_consumido != dir(lista):
        print("El almacenamiento se ha llenado de manera no esperada.")
else:
    print("El almacenamiento está lleno. No se pueden agregar más elementos.")
    
print(almacenamiento & almacenamiento_consumido == almacenamiento_consumido)
